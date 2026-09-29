//
//  SyncQueueRepository.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 23/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation
import SwiftData

public protocol SyncQueueRepositoryProtocol: ModelActor {
  init(tasksDataManager: TasksDataManager)

  /// The next task the lane's worker should run, marked in flight (never a coalescing
  /// target until popped or parked). Worker-only: use `hasRunnableTask(for:)` to peek.
  func getNextTask(for queueKey: String) -> QueuedSyncTask?

  /// Whether the lane has a task its worker could run, without marking anything in flight
  func hasRunnableTask(for queueKey: String) -> Bool

  func pop(_ task: QueuedSyncTask)

  func getAllQueueKeys() -> [String]

  func storeTask(parameters: [String: Any]) async throws

  /// Every queued task across all lanes in stored order — a display-level list, so
  /// `parameters` is left empty (workers reload payloads through `getNextTask`)
  func getAllTasks() async -> [QueuedSyncTask]

  // Set<String> (not the @MainActor TaskProgressTracker map): only the ids cross the actor
  // boundary — the tracker object is non-Sendable.
  func getOrderedTasks(activeTaskIDs: Set<String>) async -> [QueuedSyncTask]

  func getTasksCount(in queueKey: String) -> Int

  func getAllTasksWithParams(in queueKey: String) -> [SyncTask]

  /// The tasks that can lead to a book file upload, read in one go (the sync lane's
  /// `.upload`s and media-server file jobs first, then the upload lane): only their payloads
  /// are fetched, not every bookmark or move job's
  func getUploadCandidates() -> [UploadCandidate]

  func hasUploadTask(for relativePath: String) -> Bool

  /// Stores each upload-lane task unless its book already has an upload queued in either
  /// lane, parked ones included. Returns how many were stored.
  func storeFileUploadsIfAbsent(_ parameterList: [[String: Any]]) async throws -> Int

  func applyMatchUuidConflicts(_ conflicts: [ItemConflict]) throws

  func clearAll(in queueKey: String) throws

  func clearAll() throws

  /// Parks the task. Returns the stored pause (carrying any earlier `sentryEventId`), or
  /// nil when the task is gone (popped or cleared meanwhile).
  @discardableResult
  func park(taskId: String, pause: TaskPause) -> TaskPause?

  /// Returns a parked task to pending. Resuming one account-level pause resumes them all:
  /// they share one cause.
  func resume(taskId: String)

  /// Returns every parked task to pending (the one automatic retry, at launch)
  func resumeAllPaused()

  /// Remembers the Sentry event that reported this task's pause
  func setSentryEventId(_ eventId: String, forTask taskId: String)

  /// Persists a multipart upload's progress-independent state, so a relaunch resumes the
  /// same S3 upload instead of starting over. A nil `uploadId` forgets the open upload.
  /// `false` when the task is gone (cleared by a logout or lapse mid-upload): stop uploading.
  @discardableResult
  func saveUploadState(_ state: MultipartUploadState, forTask taskId: String) -> Bool
}

/// What a multipart upload must remember across launches (the parts themselves are read
/// back from S3). `uploadId` alone decides resume vs start: the sizes only count while it's
/// set (0 means unset, and the server rejects 0).
public struct MultipartUploadState: Equatable, Sendable {
  public var uploadId: String?
  public var partSize: Int
  public var fileSize: Int64
  public var restartCount: Int

  public init(uploadId: String?, partSize: Int, fileSize: Int64, restartCount: Int) {
    self.uploadId = uploadId
    self.partSize = partSize
    self.fileSize = fileSize
    self.restartCount = restartCount
  }

  /// Read back from an `uploadFile` task's parameters (`UploadFileTaskModel.toDictionaryPayload`)
  public init(parameters: [String: Any]) {
    self.init(
      uploadId: parameters["uploadId"] as? String,
      partSize: parameters["partSize"] as? Int ?? 0,
      fileSize: parameters["fileSize"] as? Int64 ?? 0,
      restartCount: parameters["restartCount"] as? Int ?? 0
    )
  }
}

public actor SyncQueueRepository: SyncQueueRepositoryProtocol, BPLogger {
  nonisolated public let modelContainer: ModelContainer
  nonisolated public let modelExecutor: any ModelExecutor

  private let tasksDataManager: TasksDataManager
  /// The task each lane's worker is running: handed out by `getNextTask`, dropped on pop
  /// or park. Its parameters were already read, so it must never be a coalescing target —
  /// and once parking exists it isn't always the lane's first row (a Retry can put a
  /// resumed task ahead of it).
  private var inFlightTaskIDs: [String: String] = [:]

  public init(tasksDataManager: TasksDataManager) {
    self.modelContainer = tasksDataManager.container
    let modelContext = ModelContext(tasksDataManager.container)
    // Every mutating method saves explicitly (pop even has a save→rollback→re-save
    // retry) — autosave would make persistence timing nondeterministic
    modelContext.autosaveEnabled = false
    self.modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
    self.tasksDataManager = tasksDataManager
  }

  public func getNextTask(for queueKey: String) -> QueuedSyncTask? {
    guard let (reference, storedObject) = nextRunnableTask(for: queueKey) else { return nil }

    inFlightTaskIDs[queueKey] = reference.taskID
    return QueuedSyncTask(
      id: reference.taskID,
      queueKey: reference.queueKey,
      jobType: reference.jobType,
      parameters: storedObject.toDictionaryPayload(),
      uuid: reference.uuid,
      relativePath: reference.relativePath,
      pause: reference.pause
    )
  }

  public func hasRunnableTask(for queueKey: String) -> Bool {
    nextRunnableTask(for: queueKey) != nil
  }

  /// The pause rules: `.task` rows are skipped, a `.lane`/`.account` head stops the lane,
  /// and any `.account` pause holds every server lane
  private func nextRunnableTask(
    for queueKey: String
  ) -> (QueuedTaskReferenceModel, any DictionaryConvertible)? {
    guard let tasksContainer = fetchGlobalQueueModel() else { return nil }

    if TaskQueueKey.isServerLane(queueKey),
       tasksContainer.tasks.contains(where: { $0.pauseScopeValue == .account }) {
      return nil
    }

    for reference in tasksContainer.orderedTasks(for: queueKey) {
      switch reference.pauseScopeValue {
      case .task:
        continue
      case .lane, .account:
        return nil
      case nil:
        break
      }

      guard
        let storedObject = tasksDataManager.getTaskModel(
          with: reference.taskID,
          jobType: reference.jobType,
          in: modelContext
        )
      else {
        /// Drop dangling references (payload missing) instead of stalling the queue
        tasksContainer.tasks.removeAll(where: { $0.id == reference.id })
        modelContext.delete(reference)
        do {
          try modelContext.save()
        } catch {
          // Unsaved = the dangling reference resurfaces on the next getNextTask pass;
          // log like every other save site so repeats are diagnosable
          Self.logger.error("Failed to persist dangling-reference cleanup: \(error)")
        }
        tasksDataManager.notifyTasksChanged(context: modelContext)
        continue
      }

      return (reference, storedObject)
    }

    return nil
  }

  @discardableResult
  public func park(taskId: String, pause: TaskPause) -> TaskPause? {
    clearInFlight(taskId)
    guard
      let reference = fetchGlobalQueueModel()?.tasks.first(where: { $0.taskID == taskId })
    else { return nil }

    reference.pauseScope = pause.scope.rawValue
    reference.errorCode = pause.errorCode
    reference.errorMessage = pause.message
    reference.httpStatus = pause.httpStatus
    reference.pausedAt = pause.pausedAt
    saveAndNotify("park \(taskId)")
    return reference.pause
  }

  public func resume(taskId: String) {
    guard
      let tasks = fetchGlobalQueueModel()?.tasks,
      let reference = tasks.first(where: { $0.taskID == taskId }),
      let scope = reference.pauseScopeValue
    else { return }

    if scope == .account {
      tasks.filter { $0.pauseScopeValue == .account }.forEach { $0.clearPause() }
    } else {
      reference.clearPause()
    }
    saveAndNotify("resume \(taskId)")
  }

  public func resumeAllPaused() {
    let paused = fetchGlobalQueueModel()?.tasks.filter { $0.pauseScope != nil } ?? []
    guard !paused.isEmpty else { return }

    paused.forEach { $0.clearPause() }
    saveAndNotify("resume all paused tasks")
  }

  public func setSentryEventId(_ eventId: String, forTask taskId: String) {
    guard
      let reference = fetchGlobalQueueModel()?.tasks.first(where: { $0.taskID == taskId })
    else { return }

    reference.sentryEventId = eventId
    saveAndNotify("record the report of \(taskId)")
  }

  @discardableResult
  public func saveUploadState(_ state: MultipartUploadState, forTask taskId: String) -> Bool {
    guard
      let task = try? modelContext.fetch(
        FetchDescriptor<UploadFileTaskModel>(predicate: #Predicate { $0.id == taskId })
      ).first
    else {
      Self.logger.info("Upload task \(taskId) is gone; its state wasn't saved")
      return false
    }

    task.uploadId = state.uploadId
    task.partSize = state.partSize
    task.fileSize = state.fileSize
    task.restartCount = state.restartCount
    do {
      try modelContext.save()
    } catch {
      Self.logger.error("Failed to persist the upload state of \(taskId): \(error)")
    }
    return true
  }

  private func clearInFlight(_ taskId: String) {
    inFlightTaskIDs = inFlightTaskIDs.filter { $0.value != taskId }
  }

  private func saveAndNotify(_ action: String) {
    do {
      try modelContext.save()
    } catch {
      Self.logger.error("Failed to persist \(action): \(error)")
    }
    tasksDataManager.notifyTasksChanged(context: modelContext)
  }

  public func pop(_ task: QueuedSyncTask) {
    clearInFlight(task.id)
    guard let tasksContainer = fetchGlobalQueueModel() else { return }

    let context = modelContext

    try? tasksDataManager.deleteTaskModel(
      with: task.id,
      jobType: task.jobType,
      context: context
    )

    if let reference = tasksContainer.tasks.first(where: { $0.taskID == task.id }) {
      tasksContainer.tasks.removeAll(where: { $0.id == reference.id })
      context.delete(reference)
    }

    // Removal happens ONLY here (getNextTask never removes): a silently-failed save leaves the
    // reference behind and the worker re-runs the same task forever. Retry once after a
    // rollback, then surface loudly.
    do {
      try context.save()
    } catch {
      Self.logger.error("Failed to persist task removal (\(task.id)), retrying: \(error)")
      context.rollback()
      // rollback() undid the payload delete above too — re-issue it or the payload
      // row stays orphaned until the next clearAll()
      try? tasksDataManager.deleteTaskModel(
        with: task.id,
        jobType: task.jobType,
        context: context
      )
      if let reference = tasksContainer.tasks.first(where: { $0.taskID == task.id }) {
        tasksContainer.tasks.removeAll(where: { $0.id == reference.id })
        context.delete(reference)
      }
      do {
        try context.save()
      } catch {
        Self.logger.error("Task removal persistently failing (\(task.id)) — the worker will re-run it: \(error)")
      }
    }

    tasksDataManager.notifyTasksChanged(context: context)
  }

  private func fetchGlobalQueueModel() -> SyncQueueContainer? {
    let context = modelContext

    let descriptor = FetchDescriptor<SyncQueueContainer>()
    let containers = try? context.fetch(descriptor)

    guard let tasksContainer = containers?.first else {
      return nil
    }

    return tasksContainer
  }

  public func getAllQueueKeys() -> [String] {
    return fetchGlobalQueueModel()?.allQueueKeys ?? []
  }

  public func storeTask(parameters: [String: Any]) async throws {
    guard
      let taskId = parameters["id"] as? String,
      let rawJobType = parameters["jobType"] as? String,
      let jobType = SyncJobType(rawValue: rawJobType),
      let queueKey = parameters["queueKey"] as? String
    else {
      throw BookPlayerError.runtimeError("Missing id, job type or queue key when creating task")
    }

    let context = modelContext

    // Get or create the tasks container
    let descriptor = FetchDescriptor<SyncQueueContainer>()
    let containers = try context.fetch(descriptor)
    let tasksContainer = containers.first ?? SyncQueueContainer()

    if containers.isEmpty {
      context.insert(tasksContainer)
    }

    if coalesceTaskIfPossible(
      jobType: jobType,
      queueKey: queueKey,
      parameters: parameters,
      tasksContainer: tasksContainer
    ) {
      try context.save()
      tasksDataManager.notifyTasksChanged(context: context)
      return
    }

    tasksDataManager.createTaskModel(for: jobType, with: parameters, in: context)

    let nextPosition = (tasksContainer.tasks.map(\.position).max() ?? -1) + 1
    // Create task reference
    let taskReference = QueuedTaskReferenceModel(
      queueKey: queueKey,
      taskID: taskId,
      jobType: jobType,
      position: nextPosition,
      uuid: parameters["uuid"] as? String ?? "",
      relativePath: parameters["relativePath"] as? String ?? ""
    )

    // Add to container
    tasksContainer.tasks.append(taskReference)
    taskReference.container = tasksContainer

    try context.save()
    tasksDataManager.notifyTasksChanged(context: context)

    NotificationCenter.default.post(
      name: .newTaskInQueue,
      object: nil,
      userInfo: ["queueKey": queueKey]
    )
  }

  /// Merge the new task into an equivalent queued one when possible, so the queue
  /// doesn't accumulate redundant work. The running task is never a merge target: its
  /// parameter snapshot was already read by `getNextTask`, so mutations would be silently
  /// dropped when it finishes and gets deleted.
  private func coalesceTaskIfPossible(
    jobType: SyncJobType,
    queueKey: String,
    parameters: [String: Any],
    tasksContainer: SyncQueueContainer
  ) -> Bool {
    /// Parked tasks are never merge targets (new work would wait behind their failure),
    /// nor is the running one: its parameters were already read. It used to be the lane's
    /// first row, but a Retry can now put a resumed task ahead of it, so it's excluded by id.
    let mergeableReferences = tasksContainer.orderedTasks(for: queueKey).filter {
      $0.pauseScope == nil && $0.taskID != inFlightTaskIDs[queueKey]
    }

    switch jobType {
    case .matchUuid:
      guard
        let newUuidsDict = parameters["uuids"] as? [String: String],
        let candidateReference = mergeableReferences.last(where: { $0.jobType == .matchUuid }),
        let candidateTask = try? modelContext
          .fetch(FetchDescriptor<MatchUuidsTaskModel>())
          .first(where: { $0.id == candidateReference.taskID })
      else {
        return false
      }

      /// Prefer existing values so we never overwrite uuids that other queued tasks or
      /// Core Data are already referencing
      var merged = candidateTask.uuids
      for (path, uuid) in newUuidsDict where merged[path] == nil {
        merged[path] = uuid
      }
      /// Past the server's per-request limit the merged task could never succeed: queue a
      /// separate task instead
      guard merged.count <= SyncJobScheduler.matchUuidsBatchLimit else {
        return false
      }
      candidateTask.uuids = merged
      return true

    case .update:
      guard
        let uuid = parameters["uuid"] as? String,
        let candidateReference = mergeableReferences.last(where: { $0.jobType == .update && $0.uuid == uuid }),
        let candidateTask = try? modelContext
          .fetch(FetchDescriptor<UpdateTaskModel>())
          .first(where: { $0.id == candidateReference.taskID })
      else {
        return false
      }

      var parameters = parameters
      parameters["id"] = candidateTask.id
      tasksDataManager.updateTaskModel(candidateTask, with: parameters)
      return true

    case .externalUpdate:
      guard let providerId = parameters["providerId"] as? String else {
        return false
      }
      // The reference doesn't carry providerId, so match through the fetched tasks:
      // taking just the LAST externalUpdate reference misses whenever the queue holds
      // pushes for more than one book, creating a duplicate task instead of coalescing
      let externalTasks = (try? modelContext.fetch(FetchDescriptor<ExternalUpdateTaskModel>())) ?? []
      let tasksByID = Dictionary(
        uniqueKeysWithValues: externalTasks
          .filter { $0.providerId == providerId }
          .map { ($0.id, $0) }
      )
      guard
        let candidateReference = mergeableReferences.last(where: {
          $0.jobType == .externalUpdate && tasksByID[$0.taskID] != nil
        }),
        let candidateTask = tasksByID[candidateReference.taskID]
      else {
        return false
      }

      tasksDataManager.updateExternalUpdateTaskModel(for: candidateTask, with: parameters, in: modelContext)
      return true

    default:
      return false
    }
  }

  public func getAllTasks() async -> [QueuedSyncTask] {
    guard let tasksContainer = fetchGlobalQueueModel() else { return [] }

    return tasksContainer.orderedTasks.map { task in
      QueuedSyncTask(
        id: task.taskID,
        queueKey: task.queueKey,
        jobType: task.jobType,
        parameters: [:],
        uuid: task.uuid,
        relativePath: task.relativePath,
        pause: task.pause
      )
    }
  }

  public func getOrderedTasks(activeTaskIDs: Set<String>) async -> [QueuedSyncTask] {
    let concurrentTasks = await self.getAllTasks()

    let activeGroup = concurrentTasks.filter { task in
      activeTaskIDs.contains(task.id)
    }

    // 2. Sieve out ONLY the tasks that are NOT active.
    let inactiveGroup = concurrentTasks.filter { task in
      !activeTaskIDs.contains(task.id)
    }

    // 3. Merge them back together, active ones first!
    return activeGroup + inactiveGroup
  }

  public func getTasksCount(in queueKey: String) -> Int {
    guard let tasksContainer = fetchGlobalQueueModel() else { return 0 }

    return tasksContainer.tasks.filter { $0.queueKey == queueKey }.count
  }

  public func getUploadCandidates() -> [UploadCandidate] {
    guard let tasksContainer = fetchGlobalQueueModel() else { return [] }

    let syncCandidates = tasksContainer.orderedTasks(for: TaskQueueKey.sync).filter {
      $0.jobType == .upload || $0.jobType == .externalResourceToDownload
    }
    let uploads = tasksContainer.orderedTasks(for: TaskQueueKey.uploadFile)
    // One fetch per payload type, not per task: this runs on every queue change during a
    // continued run, on the actor the workers need
    var payloads = [String: any DictionaryConvertible]()
    do {
      for model in try modelContext.fetch(FetchDescriptor<UploadTaskModel>()) {
        payloads[model.id] = model
      }
      for model in try modelContext.fetch(FetchDescriptor<ExternalResourceToDownloadTaskModel>()) {
        payloads[model.id] = model
      }
      for model in try modelContext.fetch(FetchDescriptor<UploadFileTaskModel>()) {
        payloads[model.id] = model
      }
    } catch {
      // Read as "nothing waiting", which can end a continued run early: make it traceable
      Self.logger.error("Failed to read the upload candidates: \(error)")
    }
    return (syncCandidates + uploads).compactMap { taskRef in
      guard let storedObject = payloads[taskRef.taskID] else { return nil }

      return UploadCandidate(
        task: SyncTask(
          id: taskRef.taskID,
          uuid: taskRef.uuid,
          relativePath: taskRef.relativePath,
          jobType: taskRef.jobType,
          parameters: storedObject.toDictionaryPayload()
        ),
        queueKey: taskRef.queueKey,
        isParked: taskRef.pauseScope != nil
      )
    }
  }

  public func getAllTasksWithParams(in queueKey: String) -> [SyncTask] {
    guard let tasksContainer = fetchGlobalQueueModel() else { return [] }

    return tasksContainer.orderedTasks(for: queueKey).compactMap { taskRef in
      guard
        let storedObject = tasksDataManager.getTaskModel(
          with: taskRef.taskID,
          jobType: taskRef.jobType,
          in: modelContext
        )
      else {
        return nil
      }

      return SyncTask(
        id: taskRef.taskID,
        uuid: taskRef.uuid,
        relativePath: taskRef.relativePath,
        jobType: taskRef.jobType,
        parameters: storedObject.toDictionaryPayload()
      )
    }
  }

  /// Checked and stored in one actor turn, so an upload queued meanwhile can't be doubled.
  /// One save and one change notice for the whole batch: a LITE → PRO backlog can be
  /// thousands of books, and a store per task would hold the actor for each of them
  public func storeFileUploadsIfAbsent(_ parameterList: [[String: Any]]) async throws -> Int {
    var queued = Set(getUploadCandidates().map(\.task.uuid))
    let context = modelContext
    let containers = try context.fetch(FetchDescriptor<SyncQueueContainer>())
    let tasksContainer = containers.first ?? SyncQueueContainer()
    if containers.isEmpty {
      context.insert(tasksContainer)
    }
    var nextPosition = (tasksContainer.tasks.map(\.position).max() ?? -1) + 1
    var stored = 0
    for parameters in parameterList {
      guard
        let taskId = parameters["id"] as? String,
        let uuid = parameters["uuid"] as? String,
        !queued.contains(uuid)
      else { continue }
      // Upload-lane tasks never coalesce: each is its book's one upload
      tasksDataManager.createTaskModel(for: .uploadFile, with: parameters, in: context)
      let taskReference = QueuedTaskReferenceModel(
        queueKey: TaskQueueKey.uploadFile,
        taskID: taskId,
        jobType: .uploadFile,
        position: nextPosition,
        uuid: uuid,
        relativePath: parameters["relativePath"] as? String ?? ""
      )
      tasksContainer.tasks.append(taskReference)
      taskReference.container = tasksContainer
      nextPosition += 1
      queued.insert(uuid)
      stored += 1
    }
    guard stored > 0 else { return 0 }

    try context.save()
    tasksDataManager.notifyTasksChanged(context: context)
    NotificationCenter.default.post(
      name: .newTaskInQueue,
      object: nil,
      userInfo: ["queueKey": TaskQueueKey.uploadFile]
    )
    return stored
  }

  /// Check if there's an upload task queued for the item
  public func hasUploadTask(for relativePath: String) -> Bool {
    do {
      let descriptor = FetchDescriptor<UploadTaskModel>(
        predicate: #Predicate<UploadTaskModel> { task in
          task.relativePath == relativePath
        }
      )

      let tasks = try modelContext.fetch(descriptor)
      return !tasks.isEmpty

    } catch {
      return false
    }
  }

  /// Rewrites task reference and task model uuids for each conflict returned by `matchUuid`.
  /// Each conflict maps a locally-known uuid (`key`) to the uuid the server wants the client
  /// to adopt (`uuid`). Runs on the actor's serial executor.
  public func applyMatchUuidConflicts(_ conflicts: [ItemConflict]) throws {
    for conflict in conflicts {
      let oldUuid = conflict.key
      let newUuid = conflict.uuid
      let refs = try modelContext.fetch(
        FetchDescriptor<QueuedTaskReferenceModel>(predicate: #Predicate { $0.uuid == oldUuid })
      )
      for ref in refs {
        ref.uuid = newUuid
        let taskId = ref.taskID
        switch ref.jobType {
        case .upload:
          if let task = try modelContext.fetch(
            FetchDescriptor<UploadTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        case .update:
          if let task = try modelContext.fetch(
            FetchDescriptor<UpdateTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        case .move:
          if let task = try modelContext.fetch(
            FetchDescriptor<MoveTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        case .renameFolder:
          if let task = try modelContext.fetch(
            FetchDescriptor<RenameFolderTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        case .delete, .shallowDelete:
          if let task = try modelContext.fetch(
            FetchDescriptor<DeleteTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        case .setBookmark:
          if let task = try modelContext.fetch(
            FetchDescriptor<SetBookmarkTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        case .deleteBookmark:
          if let task = try modelContext.fetch(
            FetchDescriptor<DeleteBookmarkTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        case .uploadArtwork:
          if let task = try modelContext.fetch(
            FetchDescriptor<ArtworkUploadTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        case .matchUuid, .externalUpdate:
          break
        case .externalResource:
          if let task = try modelContext.fetch(
            FetchDescriptor<UploadExternalResourceTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        case .externalResourceToDownload:
          if let task = try modelContext.fetch(
            FetchDescriptor<ExternalResourceToDownloadTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        case .deleteExternalResource:
          if let task = try modelContext.fetch(
            FetchDescriptor<DeleteExternalResourceTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        case .uploadFile:
          if let task = try modelContext.fetch(
            FetchDescriptor<UploadFileTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        }
      }
    }
    try modelContext.save()
  }

  public func clearAll(in queueKey: String) throws {
    inFlightTaskIDs[queueKey] = nil
    guard let tasksContainer = fetchGlobalQueueModel() else { return }

    let context = modelContext

    for reference in tasksContainer.orderedTasks(for: queueKey) {
      try? tasksDataManager.deleteTaskModel(
        with: reference.taskID,
        jobType: reference.jobType,
        context: context
      )
      tasksContainer.tasks.removeAll(where: { $0.id == reference.id })
      context.delete(reference)
    }

    try context.save()

    tasksDataManager.notifyTasksChanged(context: context)
  }

  public func clearAll() throws {
    inFlightTaskIDs.removeAll()
    try tasksDataManager.deleteAllTasks(with: modelContext)
  }
}

extension QueuedTaskReferenceModel {
  var pauseScopeValue: TaskPauseScope? {
    pauseScope.flatMap(TaskPauseScope.init(rawValue:))
  }

  var pause: TaskPause? {
    guard let scope = pauseScopeValue else { return nil }
    return TaskPause(
      scope: scope,
      errorCode: errorCode ?? "",
      message: errorMessage ?? "",
      httpStatus: httpStatus,
      pausedAt: pausedAt ?? Date(),
      sentryEventId: sentryEventId
    )
  }

  /// Back to pending. `sentryEventId` stays, so a re-park isn't reported twice.
  func clearPause() {
    pauseScope = nil
    errorCode = nil
    errorMessage = nil
    httpStatus = nil
    pausedAt = nil
  }
}

/// A task that can lead to a book file upload
public struct UploadCandidate {
  public let task: SyncTask
  public let queueKey: String
  public let isParked: Bool
}
