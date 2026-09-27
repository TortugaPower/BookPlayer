//
//  SyncQueueService.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 23/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import Combine
import CoreData

public protocol SyncQueueServiceProtocol {
  var accessPolicy: [SyncJobType: Bool] { get set }

  /// Shared repository backing every task queue
  var taskContainer: SyncQueueRepositoryProtocol! { get }

  /// Last sync error information for debugging
  var lastSyncError: SyncErrorInfo? { get }

  init(maxConcurrentTasks: Int)

  func setup(
    libraryService: LibrarySyncProtocol,
    getAccessLevel: @escaping () -> AccessLevel,
    verifySyncEntitlement: @escaping () async -> Bool?,
    tasksDataManager: TasksDataManager,
    networkClient: NetworkClientProtocol,
    dataManager: DataManager
  )

  /// Pending-task counts for every lane, delivered on main; replays the current snapshot
  /// on subscribe. The engine owns all queues, so this is the single source for any count
  /// shown in the UI — per lane via `count(in:)`, or `total`.
  func observeQueueCounts() -> AnyPublisher<QueueCounts, Never>

  /// Every queued task across all lanes, the in-flight ones first (display-level list)
  func getOrderedQueuedJobs(activeTaskIDs: Set<String>) async -> [QueuedSyncTask]

  func scheduleMetadataUpdate(params: [String: Any])

  func scheduleFileUpload(params: [String: Any])


  /// Cancels in-flight BookPlayer-server operations (serial sync + S3 uploads) on a
  /// subscription lapse, leaving the tier-independent externalUpdate operations running.
  /// Logout cancels everything via the `.logout` observer instead.
  func cancelServerQueueOperations()

  /// Whether the BookPlayer-server lanes (`sync`, `uploadFile`) may run. Mirrors
  /// `SyncService.isActive`; starts off.
  var serverLanesEnabled: Bool { get }

  /// Gates the BookPlayer-server lanes without touching their persisted tasks. Off holds
  /// them (a lapsed account's tasks would otherwise be rejected by the server forever);
  /// on wakes them.
  func setServerLanesEnabled(_ enabled: Bool)

  /// The user's Retry on a parked task: back to pending, and its lane wakes
  func retryPausedTask(id: String)

  /// Remembers the Sentry event that reported a pause, so it's never reported twice
  func recordPauseReport(eventId: String, forTask taskId: String)
}

public class SyncQueueService: SyncQueueServiceProtocol, BPLogger {
  let operationQueue: OperationQueue
  public var taskContainer: SyncQueueRepositoryProtocol! // Your DB model
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
  /// Off until SyncService reports the account's sync state: workers wake in `setup`,
  /// before SyncService is set up, and a lapsed account's persisted tasks must never
  /// reach the server. Guarded by `stateLock`, together with `activeQueueKeys`.
  private var _serverLanesEnabled = false
  /// Whether coded failures park (kept, visible, retryable) or are dropped. Off on the
  /// watch, which has no Queued Tasks screen to show or retry them from. Set before `setup`.
  public var parkingEnabled = true
  /// Fresh RevenueCat read of the sync entitlement (nil = the check failed), for an
  /// account-level rejection. Its update also drives the lapse path when inactive.
  var verifySyncEntitlement: (() async -> Bool?)!
  /// The book as it stands now, by uuid — for handing an upload the server doesn't
  /// recognize back to the sync lane. Internal for @testable injection.
  lazy var findSyncableItem: (String) async -> SyncableItem? = { [weak self] uuid in
    await self?.libraryService?.fetchSyncableItem(forUuid: uuid)
  }
  /// Books handed back to the sync lane this session. A second `item_not_found` for one
  /// means re-registering doesn't help (e.g. another uuid holds its key on the server):
  /// it parks instead of cycling. Guarded by `stateLock`.
  private var handedBackUuids = Set<String>()
  private let stateLock = NSLock()
  private let policyLock = NSLock()
  private var disposeBag = Set<AnyCancellable>()
  private var listeningTask: Task<Void, Never>?
  /// Owner of the store and of the per-lane counts. Internal for @testable injection.
  var tasksDataManager: TasksDataManager!
  private var _lastSyncError: SyncErrorInfo?
  /// Last sync error information for debugging. Writers hop to main, but readers
  /// (SyncService.getLastSyncError) call from arbitrary threads — same lock
  /// treatment as accessPolicy so the cross-thread read isn't a data race.
  public private(set) var lastSyncError: SyncErrorInfo? {
    get {
      policyLock.withLock { _lastSyncError }
    }
    set {
      policyLock.withLock { _lastSyncError = newValue }
    }
  }
  // Services

  required public init(maxConcurrentTasks: Int = 4) {
    self.operationQueue = OperationQueue()
    self.operationQueue.name = "com.bookplayer.synctask.concurrent"
    // This still caps the total number of operations running simultaneously across all keys
    self.operationQueue.maxConcurrentOperationCount = maxConcurrentTasks
  }

  deinit { listeningTask?.cancel() }

  /// The service's ONLY account dependency — one read, so a closure instead of the
  /// whole AccountServiceProtocol (same narrowing as the import bus). Internal for
  /// @testable injection.
  var getAccessLevel: (() -> AccessLevel)!

  public func setup(
    libraryService: LibrarySyncProtocol,
    getAccessLevel: @escaping () -> AccessLevel,
    verifySyncEntitlement: @escaping () async -> Bool?,
    tasksDataManager: TasksDataManager,
    networkClient: NetworkClientProtocol,
    dataManager: DataManager
  ) {
    self.libraryService = libraryService
    self.getAccessLevel = getAccessLevel
    self.verifySyncEntitlement = verifySyncEntitlement
    self.networkClient = networkClient
    self.dataManager = dataManager
    self.taskContainer = SyncQueueRepository(tasksDataManager: tasksDataManager)
    self.tasksDataManager = tasksDataManager
    startListeningForNewTasks()
    bindObservers()
    bindAccountObserver()
    // Policy BEFORE workers: createOperation consults accessPolicy to decide whether a
    // persisted upload may run — waking workers first only worked because wakeUpWorkers
    // happens to suspend on the repository actor before any pop
    updateAccessPolicy(getAccessLevel())
    // The one automatic retry of parked tasks: a server-side fix (or a fixed app build)
    // gets its chance on the next launch, without retrying anything in between
    wakeUpWorkers(resumingPausedTasks: true)
  }

  /// Ownership norm (same as SyncService): the service re-derives its own per-job
  /// policy on account changes — no per-platform coordinator wiring to forget.
  /// RevenueCat updates post .accountUpdate; without this, a mid-session upgrade left
  /// the launch-time policy (file uploads still gated off) until the next app start.
  func bindAccountObserver() {
    NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self else { return }
        self.updateAccessPolicy(self.getAccessLevel())
      }
      .store(in: &disposeBag)
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
  func wakeUpWorkers(resumingPausedTasks: Bool = false) {
    // Get all unique queue keys that currently have pending tasks
    Task {
      if resumingPausedTasks {
        await taskContainer.resumeAllPaused()
      }
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

  public func observeQueueCounts() -> AnyPublisher<QueueCounts, Never> {
    return tasksDataManager.observeQueueCounts()
  }

  public var serverLanesEnabled: Bool {
    stateLock.withLock { _serverLanesEnabled }
  }

  public func setServerLanesEnabled(_ enabled: Bool) {
    let changed = stateLock.withLock {
      defer { _serverLanesEnabled = enabled }
      return _serverLanesEnabled != enabled
    }
    // Turning off needs no action here: each worker retires at its next pop
    if changed, enabled {
      wakeUpWorkers()
    }
  }

  private func enqueueNextTask(for queueKey: String) async {
    // Checked before every pop, not just at wake-up, so a worker already looping when
    // sync turns off stops after its current task instead of draining the lane
    if TaskQueueKey.isServerLane(queueKey) {
      let retired = stateLock.withLock {
        guard !_serverLanesEnabled else { return false }
        activeQueueKeys.remove(queueKey)
        return true
      }
      // Checking the flag and retiring under one lock means an enable either happened
      // before (we keep going) or will see this key inactive and wake a fresh worker
      if retired { return }
    }

    // 1. AWAIT the actor to safely fetch the next task
    guard let nextTask = await taskContainer.getNextTask(for: queueKey) else {
      // The queue is empty! Use scoped locking to remove the key.
      let _ = stateLock.withLock {
        activeQueueKeys.remove(queueKey)
      }
      // Re-check after retiring: a task stored between the empty fetch and the
      // removal above would have seen an "active" worker and skipped waking one.
      // A peek: getNextTask would mark a task in flight while another worker may be
      // running a different one
      if await taskContainer.hasRunnableTask(for: queueKey) {
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
        SyncQueueProgressMonitor.shared.updateProgress(for: nextTask.id, progress: progress)
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
          let error = (operation as? LibraryItemSyncOperation)?.error
            ?? (operation as? FileUploadOperation)?.error
          if let error {
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
          await self.handleFailedOperation(error: error, task: nextTask)
        }

        // 3. AWAIT the recursive call
        await MainActor.run {
          SyncQueueProgressMonitor.shared.clear(taskID: nextTask.id)
        }
        await self.enqueueNextTask(for: queueKey)
      }
    }

    await MainActor.run {
      SyncQueueProgressMonitor.shared.markAsProcessing(taskID: nextTask.id)
    }

    operationQueue.addOperation(operation)
  }

  /// Retry (the usual 5 s), park, drop, or confirm the account, per `SyncFailurePolicy`.
  /// Returns once the next pop may happen.
  private func handleFailedOperation(error: Error?, task: QueuedSyncTask) async {
    // The server has no such book for this upload: register it again (bookplayer-api
    // docs/multipart-uploads.md) rather than park a task the user can't fix
    if task.jobType == .uploadFile,
       SyncFailurePolicy.codedFailure(error)?.code == "item_not_found",
       stateLock.withLock({ handedBackUuids.insert(task.uuid).inserted }) {
      await handBackUpload(task)
      try? await Task.sleep(for: .seconds(5))
      return
    }

    let action = SyncFailurePolicy.action(
      for: error,
      jobType: task.jobType,
      parkingEnabled: parkingEnabled
    )
    guard action != .retry, let failure = SyncFailurePolicy.codedFailure(error) else {
      try? await Task.sleep(for: .seconds(5))
      return
    }
    let code = failure.code
    let message = failure.message
    let status = failure.httpStatus

    switch action {
    case .retry:
      break
    case .drop:
      Self.logger.error("Dropping \(task.jobType.rawValue) task \(task.id): the server answered \(code)")
      await taskContainer.pop(task)
    case .park(let scope):
      await park(task, scope: scope, code: code, message: message, status: status)
    case .verifyAccount:
      // Every server lane holds from here: the rejection is about the account, so the
      // next task would get the same answer
      guard
        let pause = await park(task, scope: .account, code: code, message: message, status: status, report: false)
      else { return }
      // Off the worker: the lanes already wait on the pause
      Task {
        // Inactive: the fetch's account update runs the lapse path, which clears these
        // lanes. Active, or the check failed: the server disagrees with RevenueCat, so the
        // tasks stay held (launch retry, Retry) and it's reported.
        guard await self.verifySyncEntitlement() != false else { return }
        self.reportPause(of: task, pause: pause)
      }
    }
  }

  /// Re-registers the book through the sync lane like a fresh upload — the item, its
  /// external resources and bookmarks (`SyncService.handleItemsToUpload`); the `.upload`'s
  /// answer schedules a new upload task — or drops the upload when the book is gone
  /// locally too. The replacement is stored before this task is popped, so a kill in
  /// between can't lose the upload.
  private func handBackUpload(_ task: QueuedSyncTask) async {
    // Before the new job links the file again at the same path
    cleanUpDroppedUploadTempLink(task)
    guard let item = await findSyncableItem(task.uuid) else {
      Self.logger.info("Dropping upload \(task.id): the book is gone on the server and on this device")
      await taskContainer.pop(task)
      return
    }
    Self.logger.info("Upload \(task.id): the server lost the book, registering it again")
    let scheduler = SyncJobScheduler(tasksRepository: taskContainer)
    await scheduler.scheduleLibraryItemUploadJob(for: item)
    let itemOrigin = LibraryItemRef(relativePath: item.relativePath, uuid: item.uuid)
    for resource in item.externalResources ?? [] {
      await scheduler.scheduleExternalResourceUpload(for: resource, itemOrigin: itemOrigin)
    }
    // Bookmarks are read on the view context
    let libraryService = libraryService
    let bookmarks = await MainActor.run {
      libraryService?.getBookmarks(of: .user, relativePath: item.relativePath) ?? []
    }
    for bookmark in bookmarks {
      await scheduler.scheduleSetBookmarkJob(
        with: bookmark.relativePath,
        time: floor(bookmark.time),
        note: bookmark.note,
        for: item.uuid
      )
    }
    // A media-server book's metadata upload never schedules its file (streamed books have
    // none yet): queue the file last, the way a finished download does
    if item.mediaServerProviderName != nil {
      await scheduler.scheduleResourceToDownload(with: item.relativePath, for: item.uuid)
    }
    await taskContainer.pop(task)
  }

  @discardableResult
  private func park(
    _ task: QueuedSyncTask,
    scope: TaskPauseScope,
    code: String,
    message: String,
    status: Int?,
    report: Bool = true
  ) async -> TaskPause? {
    Self.logger.error("Pausing \(task.jobType.rawValue) task \(task.id) (\(scope.rawValue)): failed with \(code)")
    guard
      let pause = await taskContainer.park(
        taskId: task.id,
        pause: TaskPause(scope: scope, errorCode: code, message: message, httpStatus: status, pausedAt: Date())
      )
    else { return nil }
    if report {
      reportPause(of: task, pause: pause)
    }
    return pause
  }

  /// Once per task: a re-park after a launch retry or Retry was already reported
  private func reportPause(of task: QueuedSyncTask, pause: TaskPause) {
    guard pause.sentryEventId == nil else { return }
    let parked = QueuedSyncTask(
      id: task.id,
      queueKey: task.queueKey,
      jobType: task.jobType,
      parameters: [:],
      uuid: task.uuid,
      relativePath: task.relativePath,
      pause: pause
    )
    Task { @MainActor in
      NotificationCenter.default.post(name: .syncTaskPaused, object: parked)
    }
  }

  public func retryPausedTask(id: String) {
    Task {
      await taskContainer.resume(taskId: id)
      wakeUpWorkers()
    }
  }

  public func recordPauseReport(eventId: String, forTask taskId: String) {
    Task {
      await taskContainer.setSentryEventId(eventId, forTask: taskId)
    }
  }

  public func getOrderedQueuedJobs(activeTaskIDs: Set<String>) async -> [QueuedSyncTask] {
    return await taskContainer.getOrderedTasks(activeTaskIDs: activeTaskIDs)
  }

  private func createOperation(for task: QueuedSyncTask) -> AsyncOperation? {
    switch task.jobType {
    case .externalUpdate:
      guard let providerName = task.parameters["providerName"] as? String,
            let providerId = task.parameters["providerId"] as? String,
            let currentTime = task.parameters["currentTime"] as? Double,
            let percentCompleted = task.parameters["percentCompleted"] as? Double else {
        Self.logger.error("Discarding externalUpdate task \(task.id): missing required parameters")
        return nil
      }
      // The parameters are PERSISTED, so a poison value doesn't crash once — it
      // crash-loops on every pop. Int(_:) traps on NaN/infinite AND on finite values
      // beyond Int.max (CMTimeGetSeconds yields NaN for invalid CMTimes); drop the
      // task instead.
      let ticks = currentTime * 10_000_000
      // Strict <: Double(Int.max) rounds UP to 2^63, so the boundary itself would trap
      guard ticks.isFinite, ticks >= 0, ticks < Double(Int.max) else {
        Self.logger.error("Discarding externalUpdate task \(task.id): non-finite or out-of-range currentTime \(currentTime)")
        return nil
      }
      let hostId = task.parameters["hostId"] as? String
      return ExternalUpdateProgressOperation(
        providerName: providerName,
        providerItemId: providerId,
        positionTicks: Int(ticks),
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
        cleanUpDroppedUploadTempLink(task)
        return nil
      }
      guard let filePath = task.parameters["filePath"] as? String,
            let fileURL = URL(string: filePath),
            let uuid = task.parameters["uuid"] as? String else {
        Self.logger.error("Discarding uploadFile task \(task.id): missing or malformed parameters")
        cleanUpDroppedUploadTempLink(task)
        return nil
      }
      let libraryService = libraryService
      return FileUploadOperation(
        taskId: task.id,
        uuid: uuid,
        fileURL: fileURL,
        state: MultipartUploadState(parameters: task.parameters),
        client: networkClient,
        repository: taskContainer,
        libraryFileURL: { uuid in
          guard let relativePath = await libraryService?.fetchRelativePath(forUuid: uuid) else { return nil }
          return DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)
        }
      )
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
  private func handleFinishedOperation(_ operation: AsyncOperation, task: QueuedSyncTask) async {
    // The server sets synced:true itself when it assembles a multipart upload; there is
    // nothing to confirm. uploadCompleted (S3 has the file), NOT didSucceed: a consumed
    // task (its file gone) also reports didSucceed.
    if let uploadOperation = operation as? FileUploadOperation {
      if uploadOperation.uploadCompleted {
        NotificationCenter.default.post(name: .uploadCompleted, object: nil)
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
      /// Provider-backed items don't upload their file from the metadata upload: it goes
      /// up once downloaded, through the `externalResourceToDownload` job (which carries no
      /// `provider`, so its result schedules the upload here)
      if task.parameters["provider"] as? String == nil {
        handleUploadResult(result)
      } else {
        SyncJobScheduler.removeHardLink(at: URL(string: result.filePath))
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

  /// The server answered the metadata upload with a URL: it needs the file's bytes
  private func handleUploadResult(_ result: UploadResponse) {
    var params: [String: Any] = [
      "filePath": result.filePath,
      "uuid": result.uuid,
    ]
    // Persisted onto the task reference, which names the row in Queued Tasks
    if let relativePath = result.relativePath {
      params["relativePath"] = relativePath
    }
    scheduleFileUpload(params: params)
  }

  public func cancelServerQueueOperations() {
    for operation in operationQueue.operations
    where operation is FileUploadOperation || operation is LibraryItemSyncOperation {
      operation.cancel()
    }
  }

  func updateAccessPolicy(_ accessLevel: AccessLevel) {
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
    // A downgrade that loses S3 access (pro→lite keeps sync active, so no cancelAllJobs
    // fires) must also stop uploads that are ALREADY running, not just future pops
    if accessPolicy[.uploadFile] != true {
      for operation in operationQueue.operations where operation is FileUploadOperation {
        operation.cancel()
      }
    }
  }

  /// A dropped uploadFile task never constructs its FileUploadOperation, so nobody else
  /// removes the schedule-time temp hard link — same temp-dir-only guard as the
  /// operation's own success/4xx/cancel cleanup paths (a real Processed-folder file
  /// must never be deleted here).
  private func cleanUpDroppedUploadTempLink(_ task: QueuedSyncTask) {
    SyncJobScheduler.removeHardLink(at: (task.parameters["filePath"] as? String).flatMap(URL.init(string:)))
  }
}

extension SyncQueueService {
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
      /// No upload will read the temp hard link scheduled for it
      SyncJobScheduler.removeHardLink(at: (params["filePath"] as? String).flatMap(URL.init(string:)))
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
