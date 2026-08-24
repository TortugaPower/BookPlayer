//
//  SyncOrchestrator.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 23/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import Combine
import CoreData

public protocol ConcurrenceServiceProtocol {
  var accessPolicy: [SyncJobType: Bool] { get set }

  /// Shared repository backing every task queue
  var taskContainer: ConcurrentTasksRepositoryProtocol! { get }

  /// Last sync error information for debugging
  var lastSyncError: SyncErrorInfo? { get }

  init(maxConcurrentTasks: Int)

  func setup(
    libraryService: LibrarySyncProtocol,
    accessLevel: AccessLevel,
    tasksDataManager: TasksDataManager,
    networkClient: NetworkClientProtocol,
    dataManager: DataManager
  )

  func observeConcurrentTasksCount() -> AnyPublisher<Int, Never>

  func getAllQueuedJobs() async -> [ConcurrentSyncTask]

  func getOrderedQueuedJobs(activeTaskIDs: Set<String>) async -> [ConcurrentSyncTask]

  /// Pending-task count per active queue; the sync queue is always listed first,
  /// even when idle
  func getQueueSummaries() async -> [QueueSummary]

  func scheduleMetadataUpdate(params: [String: Any])

  func scheduleFileUpload(params: [String: Any])

  func updateConcurrentService(_ accessLevel: AccessLevel)
}

public class ConcurrenceService: ConcurrenceServiceProtocol, BPLogger {
  let operationQueue: OperationQueue
  public var taskContainer: ConcurrentTasksRepositoryProtocol! // Your DB model
  var libraryService: LibrarySyncProtocol!
  var networkClient: NetworkClientProtocol!
  var dataManager: DataManager!

  private var _accessPolicy: [SyncJobType: Bool] = [:]
  public var accessPolicy: [SyncJobType: Bool] {
    get {
      policyLock.withLock {
        return _accessPolicy
      }
    }
    set {
      policyLock.withLock {
        _accessPolicy = newValue
      }
    }
  }
  // Tracks which queueKeys currently have an active worker looping
  private var activeQueueKeys = Set<String>()
  private let stateLock = NSLock()
  private let policyLock = NSLock()
  private var disposeBag = Set<AnyCancellable>()
  private var listeningTask: Task<Void, Never>?
  public var tasksCountService: ConcurrentTasksCountService!
  /// Last sync error information for debugging; only written on the main queue
  public private(set) var lastSyncError: SyncErrorInfo?
  // Services

  required public init(maxConcurrentTasks: Int = 4) {
    self.operationQueue = OperationQueue()
    self.operationQueue.name = "com.bookplayer.synctask.concurrent"
    // This still caps the total number of operations running simultaneously across all keys
    self.operationQueue.maxConcurrentOperationCount = maxConcurrentTasks
  }

  deinit { listeningTask?.cancel() }

  public func setup(
    libraryService: LibrarySyncProtocol,
    accessLevel: AccessLevel,
    tasksDataManager: TasksDataManager,
    networkClient: NetworkClientProtocol,
    dataManager: DataManager
  ) {
    self.libraryService = libraryService
    self.networkClient = networkClient
    self.dataManager = dataManager
    self.taskContainer = ConcurrentTasksRepository(tasksDataManager: tasksDataManager)
    self.tasksCountService = ConcurrentTasksCountService(tasksDataManager: tasksDataManager)
    startListeningForNewTasks()
    bindObservers()
    wakeUpWorkers()
    updateConcurrentService(accessLevel)
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .logout, object: nil)
      .sink(receiveValue: { [weak self] _ in
        UserDefaults.standard.set(
          false,
          forKey: Constants.UserDefaults.hasScheduledLibraryContents
        )
        // Persisted rows are wiped by resetAllJobs, but an IN-FLIGHT operation would keep
        // running (and uploading) under the next signed-in account's token without this.
        self?.operationQueue.cancelAllOperations()
      })
      .store(in: &disposeBag)

    libraryService.progressUpdatePublisher.sink { [weak self] params in
      self?.scheduleMetadataUpdate(params: params)
    }
    .store(in: &disposeBag)
  }

  private func startListeningForNewTasks() {
    // [weak self]: the for-await loop never terminates on its own, so a strong capture makes
    // the service retain itself through its task and deinit (which cancels it) never runs.
    listeningTask = Task { [weak self] in
      let stream = NotificationCenter.default.notifications(named: .newTaskInQueue)

      for await notification in stream {
        guard let self else { return }
        guard let userInfo = notification.userInfo,
              let queueKey = userInfo["queueKey"] as? String else {
          continue
        }

        // Wake up the worker!
        await startWorkerLoop(for: queueKey)
      }
    }
  }

  /// Call this when the app wakes up, or when a new task is added to the database
  func wakeUpWorkers() {
    // Get all unique queue keys that currently have pending tasks
    Task {
      // Now you can safely await the actor!
      let pendingKeys = await taskContainer.getAllQueueKeys()

      for key in pendingKeys {
        await startWorkerLoop(for: key)
      }
    }
  }

  private func startWorkerLoop(for queueKey: String) async {
    // 1. Use scoped locking to check and update the state safely
    let isAlreadyRunning = stateLock.withLock {
      // This entire block is perfectly thread-safe and synchronous
      if activeQueueKeys.contains(queueKey) {
        return true
      } else {
        activeQueueKeys.insert(queueKey)
        return false
      }
    }

    // 2. If it was already running, safely bail out
    guard !isAlreadyRunning else { return }

    // 3. Now we are safely outside the lock, so we can await!
    await enqueueNextTask(for: queueKey)
  }

  public func observeConcurrentTasksCount() -> AnyPublisher<Int, Never> {
    return tasksCountService.observeConcurrentTasksCount()
  }

  private func enqueueNextTask(for queueKey: String) async {
    // 1. AWAIT the actor to safely fetch the next task
    guard let nextTask = await taskContainer.getNextTask(for: queueKey) else {
      // The queue is empty! Use scoped locking to remove the key.
      let _ = stateLock.withLock {
        activeQueueKeys.remove(queueKey)
      }
      // Re-check after retiring: a task stored between the empty fetch and the
      // removal above would have seen an "active" worker and skipped waking one.
      if await taskContainer.getNextTask(for: queueKey) != nil {
        await startWorkerLoop(for: queueKey)
      }
      return
    }
    guard let operation = createOperation(for: nextTask) else {
      Task {
        await self.taskContainer.pop(nextTask)
        await self.enqueueNextTask(for: queueKey)
      }
      return
    }

    operation.onProgress = { progress in
      Task { @MainActor in
        ConcurrentTaskProgressMonitor.shared.updateProgress(for: nextTask.id, progress: progress)
        // Three consumers (SyncJobScheduler, the profile task views) still listen for this
        // notification with a {uuid, relativePath, progress} payload — the old poster was
        // removed with LibraryItemSyncOperation's upload path, silently freezing every
        // upload progress bar.
        NotificationCenter.default.post(
          name: .uploadProgressUpdated,
          object: nil,
          userInfo: [
            "uuid": nextTask.uuid,
            "relativePath": nextTask.relativePath,
            "progress": progress,
          ]
        )
      }
    }

    operation.completionBlock = { [weak self, weak operation] in
      // Resolve the weak refs SYNCHRONOUSLY: the queue keeps the operation alive while its
      // completionBlock runs, but the async Task below executes later — resolving there
      // could miss the operation and skip the pop, re-running the task forever. The weak
      // capture itself breaks the operation→completionBlock→operation cycle the strong
      // capture created.
      guard let self, let operation else { return }
      // 2. Bridge back into the async world inside the synchronous completion block
      Task {

        if operation.didSucceed {
          await self.handleFinishedOperation(operation, task: nextTask)
          await self.taskContainer.pop(nextTask)
        } else {
          if let syncOperation = operation as? LibraryItemSyncOperation,
             let error = syncOperation.error {
            Self.logger.error("Sync task failed: \(error.localizedDescription)")
            await MainActor.run {
              self.lastSyncError = SyncErrorInfo(
                taskId: nextTask.id,
                uuid: nextTask.uuid,
                jobType: nextTask.jobType,
                error: error.localizedDescription
              )
            }
          }
          try? await Task.sleep(for: .seconds(5))
        }

        // 3. AWAIT the recursive call
        await MainActor.run {
          ConcurrentTaskProgressMonitor.shared.clear(taskID: nextTask.id)
        }
        await self.enqueueNextTask(for: queueKey)
      }
    }

    await MainActor.run {
      ConcurrentTaskProgressMonitor.shared.markAsProcessing(taskID: nextTask.id)
    }

    operationQueue.addOperation(operation)
  }

  public func getAllQueuedJobs() async -> [ConcurrentSyncTask] {
    return await taskContainer.getAllTasks()
  }

  public func getOrderedQueuedJobs(activeTaskIDs: Set<String>) async -> [ConcurrentSyncTask] {
    return await taskContainer.getOrderedTasks(activeTaskIDs: activeTaskIDs)
  }

  public func getQueueSummaries() async -> [QueueSummary] {
    return await taskContainer.getQueueSummaries()
  }

  private func createOperation(for task: ConcurrentSyncTask) -> AsyncOperation? {
    switch task.jobType {
    case .externalUpdate:
      guard let providerName = task.parameters["providerName"] as? String,
            let providerId = task.parameters["providerId"] as? String,
            let currentTime = task.parameters["currentTime"] as? Double,
            let percentCompleted = task.parameters["percentCompleted"] as? Double else {
        Self.logger.error("Discarding externalUpdate task \(task.id): missing required parameters")
        return nil
      }
      let hostId = task.parameters["hostId"] as? String
      return ExternalUpdateProgressOperation(
        providerName: providerName,
        providerItemId: providerId,
        positionTicks: Int(currentTime * 10_000_000),
        percentCompleted: percentCompleted,
        hostId: hostId
      )
    case .uploadFile:
      // Re-check access at execution, not just at scheduling: a pro→lite downgrade keeps
      // sync active (no cancelAllJobs), but persisted uploads must not keep PUTting to S3
      // on a tier without S3 access. Returning nil pops the task — same drop treatment the
      // lapse path gives the upload queue.
      guard accessPolicy[.uploadFile] == true else {
        Self.logger.info("Dropping persisted uploadFile task \(task.id): tier has no S3 upload access")
        return nil
      }
      guard let filePath = task.parameters["filePath"] as? String,
            let remotePath = task.parameters["remotePath"] as? String,
            let fileURL = URL(string: filePath),
            let remoteURL = URL(string: remotePath),
            let uuid = task.parameters["uuid"] as? String else {
        Self.logger.error("Discarding uploadFile task \(task.id): missing or malformed parameters")
        return nil
      }
      return FileUploadOperation(fileURL: fileURL, remoteURL: remoteURL, uuid: uuid)
    default:
      /// Serial BookPlayer-server queue
      return LibraryItemSyncOperation(
        client: networkClient,
        task: SyncTask(
          id: task.id,
          uuid: task.uuid,
          relativePath: task.relativePath,
          jobType: task.jobType,
          parameters: task.parameters
        )
      )
    }
  }

  /// Post-completion side effects for finished sync tasks
  private func handleFinishedOperation(_ operation: AsyncOperation, task: ConcurrentSyncTask) async {
    // The synced:true confirmation for file-backed books happens HERE, after the bytes are
    // actually on S3 — LibraryItemSyncOperation deliberately no longer confirms when it
    // schedules a file upload (confirming before the PUT lies to the server if the upload
    // later fails permanently).
    // uploadCompleted (a real 2xx), NOT didSucceed: consumed permanent failures (missing
    // file, 4xx) also report didSucceed so the queue stops retrying, but no bytes reached
    // the server — confirming synced:true for those lies to the backend.
    if let uploadOperation = operation as? FileUploadOperation, uploadOperation.uploadCompleted {
      let provider = NetworkProvider<LibraryAPI>(client: networkClient)
      // The task is popped unconditionally after this, so a transient confirmation failure
      // would strand the item as synced:false with its bytes already on S3 — retry a few
      // times before surfacing it in lastSyncError (a later re-upload of the same item heals).
      for attempt in 1...3 {
        do {
          let _: UploadItemResponse = try await provider.request(.update(params: [
            "uuid": uploadOperation.uuid,
            "relativePath": task.relativePath,
            "synced": true
          ]))
          NotificationCenter.default.post(name: .uploadCompleted, object: nil)
          return
        } catch {
          Self.logger.error("Upload confirmation attempt \(attempt) failed for \(uploadOperation.uuid): \(error.localizedDescription)")
          if attempt < 3 { try? await Task.sleep(for: .seconds(2)) }
          else {
            await MainActor.run {
              self.lastSyncError = SyncErrorInfo(
                taskId: task.id, uuid: uploadOperation.uuid,
                jobType: .uploadFile, error: error.localizedDescription
              )
            }
          }
        }
      }
      return
    }
    guard
      let syncOperation = operation as? LibraryItemSyncOperation,
      let results = syncOperation.results
    else { return }

    switch results {
    case .matchUuid(let response):
      await handleMatchUuidsResponse(response)
    case .uploadMetadata(let result):
      /// Provider-backed items don't upload the local file; the server pulls it
      /// from the provider via `externalResourceToDownload`
      if task.parameters["provider"] as? String == nil {
        handleUploadResult(result)
      }
    }
  }

  private func handleMatchUuidsResponse(_ results: MatchUuidsResponse) async {
    guard !results.conflicts.isEmpty else { return }
    do {
      try await applyCoreDataConflicts(results.conflicts)
      try await taskContainer.applyMatchUuidConflicts(results.conflicts)
    } catch {
      Self.logger.error("Failed to apply matchUuid conflicts: \(error.localizedDescription)")
      await MainActor.run {
        self.lastSyncError = SyncErrorInfo(
          taskId: "",
          uuid: "",
          jobType: .matchUuid,
          error: error.localizedDescription
        )
      }
    }
  }

  private func applyCoreDataConflicts(_ conflicts: [ItemConflict]) async throws {
    let context = dataManager.getBackgroundContext()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      context.perform {
        do {
          let oldUuids = conflicts.map { $0.key }
          let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
          fetchRequest.predicate = NSPredicate(format: "uuid IN %@", oldUuids)
          let items = try context.fetch(fetchRequest)
          let uuidMap = Dictionary(uniqueKeysWithValues: conflicts.map { ($0.key, $0.uuid) })
          for item in items {
            if let newUuid = uuidMap[item.uuid] {
              item.uuid = newUuid
            }
          }
          try context.save()
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func handleUploadResult(_ result: UploadResponse) {
    guard let remotePath = result.remotePath else { return }

    var params: [String: Any] = [
      "filePath": result.filePath,
      "remotePath": remotePath,
      "uuid": result.uuid,
    ]
    // Persisted onto the task reference — the post-PUT synced:true confirmation posts it,
    // and an empty relativePath there mismatches the server's item key.
    if let relativePath = result.relativePath {
      params["relativePath"] = relativePath
    }
    scheduleFileUpload(params: params)
  }

  public func updateConcurrentService(_ accessLevel: AccessLevel) {
    switch accessLevel {
    case .lite:
      accessPolicy = [
        .externalUpdate: true,
        .uploadFile: false,
      ]
    case .pro:
      accessPolicy = [
        .externalUpdate: true,
        .uploadFile: true,
      ]
    default:
      // Progress pushes go to the USER'S OWN media server, not a BookPlayer-billed resource —
      // they stay available on every tier (parity with the Android app, where the media-server
      // queues are deliberately exempt from entitlement gating).
      accessPolicy = [
        .externalUpdate: true,
        .uploadFile: false,
      ]
    }
  }
}

extension ConcurrenceService {
  public func scheduleMetadataUpdate(params: [String: Any]) {
    guard accessPolicy[.externalUpdate] == true else {
      return
    }
    Task {
      guard let queueKey = params["providerName"] as? String else {
        return
      }

      var params = params
      params["id"] = UUID().uuidString
      params["jobType"] = SyncJobType.externalUpdate.rawValue
      params["queueKey"] = queueKey
      /// Override param `lastPlayDate` if it exists with the proper name
      if let lastPlayDate = params.removeValue(forKey: #keyPath(LibraryItem.lastPlayDate)) {
        params["lastPlayDateTimestamp"] = lastPlayDate
      }

      do {
        try await taskContainer.storeTask(parameters: params)
      } catch {
        Self.logger.error("Failed to schedule metadata update task: \(error)")
      }
    }
  }

  public func scheduleFileUpload(params: [String: Any]) {
    guard accessPolicy[.uploadFile] == true else {
      return
    }

    Task {
      var params = params
      params["id"] = UUID().uuidString
      params["jobType"] = SyncJobType.uploadFile.rawValue
      params["queueKey"] = TaskQueueKey.uploadFile

      do {
        try await taskContainer.storeTask(parameters: params)
      } catch {
        Self.logger.error("Failed to schedule upload file task: \(error)")
      }
    }
  }
}
