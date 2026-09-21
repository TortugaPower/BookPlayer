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

  func getNextTask(for queueKey: String) -> QueuedSyncTask?

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

  func hasUploadTask(for relativePath: String) -> Bool

  func applyMatchUuidConflicts(_ conflicts: [ItemConflict]) throws

  func clearAll(in queueKey: String) throws

  func clearAll() throws
}

public actor SyncQueueRepository: SyncQueueRepositoryProtocol, BPLogger {
  nonisolated public let modelContainer: ModelContainer
  nonisolated public let modelExecutor: any ModelExecutor

  private let tasksDataManager: TasksDataManager

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

      return QueuedSyncTask(
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

  public func pop(_ task: QueuedSyncTask) {
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

    // Removal happens ONLY here (getNextTask is a peek): a silently-failed save leaves the
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
  /// doesn't accumulate redundant work. The head of the queue is never a merge target:
  /// its parameter snapshot may already have been read by `getNextTask`, so mutations
  /// would be silently dropped when the running task finishes and gets deleted.
  private func coalesceTaskIfPossible(
    jobType: SyncJobType,
    queueKey: String,
    parameters: [String: Any],
    tasksContainer: SyncQueueContainer
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
        relativePath: task.relativePath
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
