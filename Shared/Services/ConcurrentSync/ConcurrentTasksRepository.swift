//
//  ConcurrentTasksStore.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 23/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation
import SwiftData

public protocol ConcurrentTasksRepositoryProtocol: ModelActor {
  init(tasksDataManager: TasksDataManager)

  func getNextTask(for queueKey: String) -> ConcurrentSyncTask?

  func pop(_ task: ConcurrentSyncTask)

  func getAllQueueKeys() -> [String]

  /// Pending-task count per active queue, with the sync queue always listed first
  /// (even when idle), followed by the rest alphabetically
  func getQueueSummaries() -> [QueueSummary]

  func storeTask(parameters: [String: Any]) async throws

  /// All queued tasks outside the serial sync queue
  func getAllTasks() async -> [ConcurrentSyncTask]

  // Set<String> (not the @MainActor TaskProgressTracker map): only the ids cross the actor
  // boundary — the tracker object is non-Sendable.
  func getOrderedTasks(activeTaskIDs: Set<String>) async -> [ConcurrentSyncTask]

  func getTasksCount(in queueKey: String) -> Int

  func getAllTasks(in queueKey: String, progress: [String: Double]) -> [SyncTaskReference]

  func getAllTasksWithParams(in queueKey: String) -> [SyncTask]

  func hasUploadTask(for relativePath: String) -> Bool

  func applyMatchUuidConflicts(_ conflicts: [ItemConflict]) throws

  func clearAll(in queueKey: String) throws

  func clearAll() throws
}

public actor ConcurrentTasksRepository: ConcurrentTasksRepositoryProtocol {
  nonisolated public let modelContainer: ModelContainer
  nonisolated public let modelExecutor: any ModelExecutor

  private let tasksDataManager: TasksDataManager

  public init(tasksDataManager: TasksDataManager) {
    self.modelContainer = tasksDataManager.container
    let modelContext = ModelContext(tasksDataManager.container)
    modelContext.autosaveEnabled = true
    self.modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
    self.tasksDataManager = tasksDataManager
  }

  public func getNextTask(for queueKey: String) -> ConcurrentSyncTask? {
    guard let tasksContainer = fetchGlobalQueueModel() else { return nil }

    for reference in tasksContainer.orderedTasks(for: queueKey) {
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
        try? modelContext.save()
        continue
      }

      return ConcurrentSyncTask(
        id: reference.taskID,
        queueKey: reference.queueKey,
        jobType: reference.jobType,
        parameters: storedObject.toDictionaryPayload(),
        uuid: reference.uuid,
        relativePath: reference.relativePath
      )
    }

    return nil
  }

  public func pop(_ task: ConcurrentSyncTask) {
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

    try? context.save()

    tasksDataManager.notifyTasksChanged(context: context)
  }

  private func fetchGlobalQueueModel() -> ConcurrentTasksContainer? {
    let context = modelContext

    let descriptor = FetchDescriptor<ConcurrentTasksContainer>()
    let containers = try? context.fetch(descriptor)

    guard let tasksContainer = containers?.first else {
      return nil
    }

    return tasksContainer
  }

  public func getAllQueueKeys() -> [String] {
    return fetchGlobalQueueModel()?.allQueueKeys ?? []
  }

  public func getQueueSummaries() -> [QueueSummary] {
    var countsByQueue = Dictionary(grouping: fetchGlobalQueueModel()?.tasks ?? [], by: { $0.queueKey })
      .mapValues(\.count)

    /// The sync queue is always listed, even when idle
    if countsByQueue[TaskQueueKey.sync] == nil {
      countsByQueue[TaskQueueKey.sync] = 0
    }

    return countsByQueue
      .map { QueueSummary(queueKey: $0.key, count: $0.value) }
      .sorted { lhs, rhs in
        if lhs.queueKey == TaskQueueKey.sync { return true }
        if rhs.queueKey == TaskQueueKey.sync { return false }
        return lhs.queueKey < rhs.queueKey
      }
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
    let descriptor = FetchDescriptor<ConcurrentTasksContainer>()
    let containers = try context.fetch(descriptor)
    let tasksContainer = containers.first ?? ConcurrentTasksContainer()

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
    let taskReference = ConcurrentTaskReferenceModel(
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
  /// doesn't accumulate redundant work. The head of the queue is never a merge target:
  /// its parameter snapshot may already have been read by `getNextTask`, so mutations
  /// would be silently dropped when the running task finishes and gets deleted.
  private func coalesceTaskIfPossible(
    jobType: SyncJobType,
    queueKey: String,
    parameters: [String: Any],
    tasksContainer: ConcurrentTasksContainer
  ) -> Bool {
    let queuedReferences = tasksContainer.orderedTasks(for: queueKey)
    /// Skip the head of the queue when looking for a merge target
    let mergeableReferences = queuedReferences.dropFirst()

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
      guard
        let providerId = parameters["providerId"] as? String,
        let candidateReference = mergeableReferences.last(where: { $0.jobType == .externalUpdate }),
        let candidateTask = try? modelContext
          .fetch(FetchDescriptor<ExternalUpdateTaskModel>())
          .first(where: { $0.id == candidateReference.taskID && $0.providerId == providerId })
      else {
        return false
      }

      tasksDataManager.updateExternalUpdateTaskModel(for: candidateTask, with: parameters, in: modelContext)
      return true

    default:
      return false
    }
  }

  public func getAllTasks() async -> [ConcurrentSyncTask] {
    guard let tasksContainer = fetchGlobalQueueModel() else { return [] }

    return tasksContainer.orderedTasks
      .filter { $0.queueKey != TaskQueueKey.sync }
      .map { task in
        ConcurrentSyncTask(
          id: task.taskID,
          queueKey: task.queueKey,
          jobType: task.jobType,
          parameters: [:],
          uuid: task.uuid,
          relativePath: task.relativePath
        )
      }
  }

  public func getOrderedTasks(activeTaskIDs: Set<String>) async -> [ConcurrentSyncTask] {
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

  public func getAllTasks(in queueKey: String, progress: [String: Double]) -> [SyncTaskReference] {
    guard let tasksContainer = fetchGlobalQueueModel() else { return [] }

    return tasksContainer.orderedTasks(for: queueKey).map { task in
      let key = SyncProgressKey.resolve(uuid: task.uuid, relativePath: task.relativePath)
      return SyncTaskReference(
        id: task.taskID,
        uuid: task.uuid,
        relativePath: task.relativePath,
        jobType: task.jobType,
        progress: progress[key] ?? 0.0
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
        FetchDescriptor<ConcurrentTaskReferenceModel>(predicate: #Predicate { $0.uuid == oldUuid })
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
            FetchDescriptor<ConcurrentUploadTaskModel>(predicate: #Predicate { $0.id == taskId })
          ).first { task.uuid = newUuid }
        }
      }
    }
    try modelContext.save()
  }

  public func clearAll(in queueKey: String) throws {
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
    try tasksDataManager.deleteAllTasks(with: modelContext)
  }
}
