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

public actor ConcurrentTasksRepository: ModelActor {
  nonisolated public let modelContainer: ModelContainer
  nonisolated public let modelExecutor: any ModelExecutor
  
  private let tasksDataManager: TasksDataManager
  
  init(tasksDataManager: TasksDataManager = TasksDataManager()) {
    self.modelContainer = tasksDataManager.container
    let modelContext = ModelContext(tasksDataManager.container)
    modelContext.autosaveEnabled = true
    self.modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
    self.tasksDataManager = tasksDataManager
  }
  
  func getNextTask(for queueKey: String) -> ConcurrentSyncTask? {
    let firstTask: ConcurrentTaskReferenceModel? = fetchGlobalQueueModel()?.tasks
      .filter { $0.queueKey == queueKey }
      .sorted { $0.position < $1.position }
      .first
    
    guard let task = firstTask, let storedObject = getTaskModel(
      with: task.taskID,
      jobType: task.jobType,
      in: modelContext
    ) else {
      print("NO TASKS \(firstTask?.taskID ?? "NONE")")
      return nil
    }
    return ConcurrentSyncTask(
      id: task.taskID,
      queueKey: task.queueKey,
      jobType: task.jobType,
      parameters: storedObject.toDictionaryPayload()
    )
  }
  
  func pop(_ task: ConcurrentSyncTask) {
    guard let globalQueue = fetchGlobalQueueModel() else { return }
    
    let context = modelContext
    
    let currentTask = globalQueue.tasks.first(where: { $0.taskID == task.id })
    if let myCurrentTask = currentTask {
      globalQueue.tasks.removeAll(where: { $0.id == myCurrentTask.id })
      context.delete(myCurrentTask)
    }
    
    try? context.save()
    
    tasksDataManager.notifyConcurrentTasksChanged(context: context)
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
  
  public func getTaskModel(
    with id: String,
    jobType: ExternalSyncJobType,
    in context: ModelContext
  ) -> (any DictionaryConvertible)? {
    do {
      switch jobType {
      case .update:
        let descriptor = FetchDescriptor<ExternalUpdateTaskModel>(
          predicate: #Predicate<ExternalUpdateTaskModel> { task in task.id == id }
        )
        return try context.fetch(descriptor).first
      case .uploadFile:
        let descriptor = FetchDescriptor<ConcurrentUploadTaskModel>(
          predicate: #Predicate<ConcurrentUploadTaskModel> { task in task.id == id }
        )
        
        return try context.fetch(descriptor).first
      }
    } catch {
      return nil
    }
  }
  
  public func storeTask(parameters: [String: Any]) async throws {
    guard
      let taskId = parameters["id"] as? String,
      let rawJobType = parameters["jobType"] as? String,
      let jobType = ExternalSyncJobType(rawValue: rawJobType),
      let queueKey = parameters["queueKey"] as? String
    else {
      throw BookPlayerError.runtimeError("Missing id or job type when creating task")
    }

    let context = modelContext

    // Get or create the tasks container
    let descriptor = FetchDescriptor<ConcurrentTasksContainer>()
    let containers = try context.fetch(descriptor)
    let tasksContainer = containers.first ?? ConcurrentTasksContainer()

    if containers.isEmpty {
      context.insert(tasksContainer)
    }

    tasksDataManager.createConcurrentTaskModel(for: jobType, with: parameters, in: modelContext)

    let nextPosition = (tasksContainer.tasks.map(\.position).max() ?? -1) + 1
    // Create task reference
    let taskReference = ConcurrentTaskReferenceModel(
      queueKey: queueKey,
      taskID: taskId,
      jobType: jobType,
      position: nextPosition
    )

    // Add to container
    tasksContainer.tasks.append(taskReference)
    taskReference.container = tasksContainer

    try context.save()

    tasksDataManager.notifyConcurrentTasksChanged(context: context)
    
    NotificationCenter.default.post(
      name: .newTaskInQueue,
      object: nil,
      userInfo: ["queueKey": queueKey]
    )
  }
  
  public func getAllTasks() async -> [ConcurrentSyncTask] {
    do {
      let descriptor = FetchDescriptor<ConcurrentTasksContainer>()
      let containers = try modelContext.fetch(descriptor)

      guard let tasksContainer = containers.first else { return [] }

      return tasksContainer.orderedTasks.map { task in
        ConcurrentSyncTask(
          id: task.taskID,
          queueKey: task.queueKey,
          jobType: task.jobType,
          parameters: [:]
        )
      }

    } catch {
      return []
    }
  }
  
  public func getOrderedTasks(activeTasks: [String: TaskProgressTracker]) async -> [ConcurrentSyncTask] {
    let concurrentTasks = await self.getAllTasks()
    
    let activeGroup = concurrentTasks.filter { task in
      activeTasks.keys.contains(task.id)
    }
    
    // 2. Sieve out ONLY the tasks that are NOT active.
    let inactiveGroup = concurrentTasks.filter { task in
      !activeTasks.keys.contains(task.id)
    }
    
    // 3. Merge them back together, active ones first!
    return activeGroup + inactiveGroup
  }
}
