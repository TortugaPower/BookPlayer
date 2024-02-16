//
//  SyncTasksStorage.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/1/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation

public protocol BPTasksStorageProtocol: AnyActor {
  func appendTask(parameters: [String: Any]) async throws
  func getNextTask() async throws -> SyncTask?
  func finishedTask(id: String) async throws
  func getAllTasks() async -> [SyncTask]
  func getTasksCount() async -> Int
  func clearAll() async
  /// Check if there's an upload task queued for the item
  func hasUploadTask(for relativePath: String) async -> Bool
}

/// Persist jobs in UserDefaults
public actor SyncTasksStorage: BPTasksStorageProtocol {
  private let store = UserDefaults.standard
  private lazy var uploadTasks: [String: Any] = {
    guard let tasks = store.array(forKey: Constants.UserDefaults.syncTasksQueue) as? [Data] else { return [:] }

    return tasks.reduce(into: [:], { dict, taskData in
      guard
        let taskParams = try? JSONSerialization.jsonObject(with: taskData) as? [String: Any],
        let rawJobType = taskParams["jobType"] as? String,
        let jobType = SyncJobType(rawValue: rawJobType),
        jobType == .upload,
        let relativePath = taskParams["relativePath"] as? String
      else { return }

      dict[relativePath] = taskParams
    })
  }()

  public init() {}

  public func appendTask(parameters: [String: Any]) throws {
    var storedJobs = store.array(forKey: Constants.UserDefaults.syncTasksQueue) as? [Data] ?? []

    let finalParameters: [String: Any]

    /// Merge update tasks when it's for the same item
    if storedJobs.count >= 2,
      let lastTaskData = storedJobs.last,
       let taskParams = try JSONSerialization.jsonObject(with: lastTaskData) as? [String: Any],
       let relativePath = taskParams["relativePath"] as? String,
       parameters["relativePath"] as? String == relativePath,
       let rawJobType = parameters["jobType"] as? String,
       let jobType = SyncJobType(rawValue: rawJobType),
       jobType == .update {
      finalParameters = taskParams.merging(parameters) { (_, new) in new }
      /// Remove the last item we are replacing
      storedJobs.removeLast()
    } else {
      finalParameters = parameters
    }

    let data = try JSONSerialization.data(withJSONObject: finalParameters)
    storedJobs.append(data)

    if let rawJobType = parameters["jobType"] as? String,
       let jobType = SyncJobType(rawValue: rawJobType),
       jobType == .upload,
       let relativePath = parameters["relativePath"] as? String {
      uploadTasks[relativePath] = parameters
    }

    store.set(storedJobs, forKey: Constants.UserDefaults.syncTasksQueue)
  }

  public func getNextTask() throws -> SyncTask? {
    guard
      let tasks = store.array(forKey: Constants.UserDefaults.syncTasksQueue) as? [Data],
      let taskData = tasks.first
    else { return nil }

    guard 
      let taskParams = try JSONSerialization.jsonObject(with: taskData) as? [String: Any],
      let taskId = taskParams["id"] as? String,
      let relativePath = taskParams["relativePath"] as? String,
      let rawJobType = taskParams["jobType"] as? String,
      let jobType = SyncJobType(rawValue: rawJobType)
    else {
      throw BookPlayerError.runtimeError("Failed to decode task")
    }

    return SyncTask(
      id: taskId,
      relativePath: relativePath,
      jobType: jobType,
      parameters: taskParams
    )
  }

  public func finishedTask(id: String) throws {
    var tasks = store.array(forKey: Constants.UserDefaults.syncTasksQueue)

    guard let taskData = tasks?.removeFirst() as? Data else {
      throw BookPlayerError.runtimeError("No task queued")
    }

    guard let taskParams = try JSONSerialization.jsonObject(with: taskData) as? [String: Any] else {
      throw BookPlayerError.runtimeError("Failed to decode task")
    }

    if let rawJobType = taskParams["jobType"] as? String,
       let jobType = SyncJobType(rawValue: rawJobType),
       jobType == .upload,
       let relativePath = taskParams["relativePath"] as? String {
      uploadTasks.removeValue(forKey: relativePath)
    }

    let taskId = taskParams["id"] as? String

    guard taskId == id else {
      throw BookPlayerError.runtimeError("Finished task is not the next in the queue")
    }

    store.set(tasks, forKey: Constants.UserDefaults.syncTasksQueue)
  }

  public func getAllTasks() -> [SyncTask] {
    guard let tasks = store.array(forKey: Constants.UserDefaults.syncTasksQueue) as? [Data] else { return [] }

    return tasks.compactMap({ data in
      guard
        let taskParams = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let taskId = taskParams["id"] as? String,
        let relativePath = taskParams["relativePath"] as? String,
        let rawJobType = taskParams["jobType"] as? String,
        let jobType = SyncJobType(rawValue: rawJobType)
      else {
        return nil
      }

      return SyncTask(
        id: taskId,
        relativePath: relativePath,
        jobType: jobType,
        parameters: taskParams
      )
    })
  }

  public func getTasksCount() -> Int {
    return store.array(forKey: Constants.UserDefaults.syncTasksQueue)?.count ?? 0
  }

  public func clearAll() {
    store.removeObject(forKey: Constants.UserDefaults.syncTasksQueue)
    uploadTasks = [:]
  }

  /// Check if there's an upload task queued for the item
  public func hasUploadTask(for relativePath: String) -> Bool {
    return uploadTasks[relativePath] != nil
  }
}
