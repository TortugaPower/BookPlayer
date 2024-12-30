//
//  SyncTasksStorage.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation
import RealmSwift

public protocol BPTasksStorageProtocol: AnyActor {
  func appendTask(parameters: [String: Any]) async throws
  func getNextTask() async throws -> SyncTask?
  func finishedTask(id: String) async throws
  func getAllTasks() async -> [SyncTaskReference]
  func getTasksCount() async -> Int
  func clearAll() async throws
  /// Check if there's an upload task queued for the item
  func hasUploadTask(for relativePath: String) async -> Bool
}

/// Persist jobs in UserDefaults
public actor SyncTasksStorage: BPTasksStorageProtocol {
  private var realm: Realm!

  public init() async throws {
    self.realm = try await RealmManager.shared.initializeRealm(in: self)
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

    if jobType == .update,
       (realm.objects(SyncTasksObject.self).first?.tasks.count ?? 0) > 1,
       let existingTask = realm.objects(UpdateTaskObject.self).last(where: {
         $0.relativePath == relativePath
       }) {
      var parameters = parameters
      parameters["id"] = existingTask.id

      try await realm.asyncWrite {
        realm.create(UpdateTaskObject.self, value: parameters, update: .modified)
      }
    } else {
      try await realm.asyncWrite {
        let objectType = getRealmObjectType(for: jobType)
        realm.create(objectType, value: parameters)
        let taskReference = realm.create(
          SyncTaskReferenceObject.self,
          value: [
            "id": ObjectId.generate(),
            "relativePath": relativePath,
            "taskID": taskId,
            "jobType": jobType.rawValue
          ]
        )

        let controller = realm.objects(SyncTasksObject.self).first
        ?? realm.create(SyncTasksObject.self)
        controller.tasks.append(taskReference)
      }
    }
  }

  public func getNextTask() async throws -> SyncTask? {
    guard
      let controller = realm.objects(SyncTasksObject.self).first,
      let task = controller.tasks.first
    else {
      return nil
    }

    guard 
      let storedObject = getRealmObject(with: task.taskID, jobType: task.jobType)
    else {
      try await realm.asyncWrite {
        controller.tasks.removeFirst()
      }
      return nil
    }

    return SyncTask(
      id: task.taskID,
      relativePath: task.relativePath,
      jobType: task.jobType,
      parameters: storedObject.toDictionaryPayload()
    )
  }

  private func getRealmObjectType(for jobType: SyncJobType) -> Object.Type {
    switch jobType {
    case .upload:
      return UploadTaskObject.self
    case .update:
      return UpdateTaskObject.self
    case .move:
      return MoveTaskObject.self
    case .delete, .shallowDelete:
      return DeleteTaskObject.self
    case .deleteBookmark:
      return DeleteBookmarkTaskObject.self
    case .setBookmark:
      return SetBookmarkTaskObject.self
    case .renameFolder:
      return RenameFolderTaskObject.self
    case .uploadArtwork:
      return ArtworkUploadTaskObject.self
    }
  }

  private func getRealmObject(with id: String, jobType: SyncJobType) -> Object? {
    let type = getRealmObjectType(for: jobType)

    return realm.object(ofType: type, forPrimaryKey: id)
  }

  public func finishedTask(id: String) async throws {
    guard
      let controller = realm.objects(SyncTasksObject.self).first,
      let task = controller.tasks.first
    else { return }

    try await realm.asyncWrite {
      if let storedObject = getRealmObject(with: task.taskID, jobType: task.jobType) {
        realm.delete(storedObject)
      }

      controller.tasks.removeFirst()
      realm.delete(task)
    }
  }

  public func getAllTasks() -> [SyncTaskReference] {
    guard
      let tasks = realm.objects(SyncTasksObject.self).first?.tasks
    else { return [] }

    return tasks.map { SyncTaskReference(
      id: $0.taskID,
      relativePath: $0.relativePath,
      jobType: $0.jobType
    ) }
  }

  public func getTasksCount() -> Int {
    return realm.objects(SyncTasksObject.self).first?.tasks.count ?? 0
  }

  public func clearAll() async throws {
    try await realm.asyncWrite {
      realm.deleteAll()
    }
  }

  /// Check if there's an upload task queued for the item
  public func hasUploadTask(for relativePath: String) -> Bool {
    return realm.objects(UploadTaskObject.self)
      .first { $0.relativePath == relativePath } != nil
  }
}
