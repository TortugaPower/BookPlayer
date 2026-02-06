//
//  SyncTasksStorage.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation
import SwiftData

/// Persist jobs using SwiftData
public actor SyncTasksStorage: ModelActor {
  nonisolated public let modelContainer: ModelContainer
  nonisolated public let modelExecutor: any ModelExecutor

  private let tasksDataManager: TasksDataManager
  
  init(tasksDataManager: TasksDataManager) throws {
    self.modelContainer = tasksDataManager.container
    let modelContext = ModelContext(tasksDataManager.container)
    modelContext.autosaveEnabled = true
    self.modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
    self.tasksDataManager = tasksDataManager
  }

  public func appendTask(parameters: [String: Any]) async throws {
    guard
      let taskId = parameters["id"] as? String,
      let relativePath = parameters["relativePath"] as? String,
      let rawJobType = parameters["jobType"] as? String,
      let jobType = SyncJobType(rawValue: rawJobType)
    else {
      throw BookPlayerError.runtimeError("Missing id or job type when creating task")
    }

    let context = modelContext

    // Get or create the tasks container
    let descriptor = FetchDescriptor<SyncTasksContainer>()
    let containers = try context.fetch(descriptor)
    let tasksContainer = containers.first ?? SyncTasksContainer()

    if containers.isEmpty {
      context.insert(tasksContainer)
    }

    // Check for update task optimization
    if jobType == .update,
      tasksContainer.tasks.count > 1,
      let existingTask = try context.fetch(FetchDescriptor<UpdateTaskModel>())
        .last(where: { $0.relativePath == relativePath })
    {

      var parameters = parameters
      parameters["id"] = existingTask.id

      // Update existing task
      tasksDataManager.updateTaskModel(existingTask, with: parameters)

    } else {
      // Create new task object
      tasksDataManager.createTaskModel(for: jobType, with: parameters, in: modelContext)

      let nextPosition = (tasksContainer.tasks.map(\.position).max() ?? -1) + 1
      // Create task reference
      let taskReference = SyncTaskReferenceModel(
        relativePath: relativePath,
        taskID: taskId,
        jobType: jobType,
        position: nextPosition
      )

      // Add to container
      tasksContainer.tasks.append(taskReference)
      taskReference.container = tasksContainer
    }

    try context.save()

    tasksDataManager.notifyTasksChanged(context: context)
  }

  public func getNextTask() async throws -> SyncTask? {
    let descriptor = FetchDescriptor<SyncTasksContainer>()
    let containers = try modelContext.fetch(descriptor)

    guard let tasksContainer = containers.first,
      let firstTask = tasksContainer.orderedTasks.first
    else {
      return nil
    }

    guard
      let storedObject = tasksDataManager.getTaskModel(
        with: firstTask.taskID,
        jobType: firstTask.jobType,
        in: modelContext
      )
    else {
      // Remove invalid task reference
      tasksContainer.tasks = tasksContainer.tasks.filter { $0.taskID != firstTask.taskID }
      try modelContext.save()
      return nil
    }

    return SyncTask(
      id: firstTask.taskID,
      relativePath: firstTask.relativePath,
      jobType: firstTask.jobType,
      parameters: storedObject.toDictionaryPayload()
    )
  }

  public func finishedTask(id: String, jobType: SyncJobType) async throws {
    let descriptor = FetchDescriptor<SyncTasksContainer>()
    let containers = try modelContext.fetch(descriptor)

    guard let tasksContainer = containers.first else { return }

    // Delete the actual task object
    try tasksDataManager.deleteTaskModel(
      with: id,
      jobType: jobType,
      context: modelContext
    )

    // Remove task reference
    tasksContainer.tasks = tasksContainer.tasks.filter { $0.taskID != id }

    try tasksDataManager.deleteReferenceModel(
      with: id,
      jobType: jobType,
      context: modelContext
    )

    try modelContext.save()

    tasksDataManager.notifyTasksChanged(context: modelContext)
  }

  public func getAllTasks(progress: [String: Double]) async -> [SyncTaskReference] {
    do {
      let descriptor = FetchDescriptor<SyncTasksContainer>()
      let containers = try modelContext.fetch(descriptor)

      guard let tasksContainer = containers.first else { return [] }

      return tasksContainer.orderedTasks.map { task in
        SyncTaskReference(
          id: task.taskID,
          relativePath: task.relativePath,
          jobType: task.jobType,
          progress: progress[task.relativePath] ?? 0.0
        )
      }

    } catch {
      return []
    }
  }

  public func getAllTasksWithParams() async -> [SyncTask] {
    do {
      let descriptor = FetchDescriptor<SyncTasksContainer>()
      let containers = try modelContext.fetch(descriptor)

      guard let tasksContainer = containers.first else { return [] }

      return tasksContainer.orderedTasks.compactMap { taskRef in
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
          relativePath: taskRef.relativePath,
          jobType: taskRef.jobType,
          parameters: storedObject.toDictionaryPayload()
        )
      }

    } catch {
      return []
    }
  }

  public func getTasksCount() -> Int {
    tasksDataManager.getTasksCount()
  }

  public func clearAll() async throws {
    try tasksDataManager.deleteAllTasks(with: modelContext)
  }

  /// Check if there's an upload task queued for the item
  public func hasUploadTask(for relativePath: String) async -> Bool {
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
}
