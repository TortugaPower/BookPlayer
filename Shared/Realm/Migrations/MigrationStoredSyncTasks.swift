//
//  MigrationStoredSyncTasks.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/2/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import RealmSwift

class MigrationStoredSyncTasks: MigrationHandler {
  let version: UInt64 = 1

  func migrate(_ migration: RealmSwift.Migration, _ oldSchemaVersion: UInt64) {
    guard oldSchemaVersion < version else { return }

    let taskObjects1 = migrateSyncTasksFromThirdParty(migration)
    let taskObjects2 = migrateSyncTasksFromUserDefaults(migration)

    let tasks = taskObjects1 + taskObjects2

    migration.create("SyncTasksObject", value: ["tasks": tasks])
  }

  /// Migrate tasks from stored sync task from third party library
  private func migrateSyncTasksFromThirdParty(_ migration: RealmSwift.Migration) -> [MigrationObject] {
    let store = UserDefaults.standard
    let values: [String: [String: String]] = store.value(forKey: "LibraryItemSyncJob") as? [String: [String: String]] ?? [:]
    let dictionaryTasks: [String: String] = values["GLOBAL"] ?? [:]
    let storedTasks = Array(dictionaryTasks.values)

    guard !storedTasks.isEmpty else { return [] }

    var tasks = [MigrationObject]()

    for storedTask in storedTasks {
      autoreleasepool {
        if let taskData = storedTask.data(using: .utf8),
           let taskDictionary = try? JSONSerialization.jsonObject(with: taskData) as? [String: Any],
           let taskRawParams = taskDictionary["params"] as? String,
           let taskParamsData = taskRawParams.data(using: .utf8),
           var taskParams = try? JSONSerialization.jsonObject(with: taskParamsData) as? [String: Any],
           let relativePath = taskParams["relativePath"] as? String,
           let jobTypeRaw = taskParams["jobType"] as? String,
           let jobType = SyncJobType(rawValue: jobTypeRaw) {
          let taskId = UUID().uuidString
          taskParams["id"] = taskId

          if taskParams["lastPlayDateTimestamp"] is String {
            taskParams["lastPlayDateTimestamp"] = 0
          }

          let task = migrateTask(
            taskParams,
            id: taskId,
            relativePath: relativePath,
            jobType: jobType,
            migration: migration
          )
          tasks.append(task)
        }
      }
    }

    store.removeObject(forKey: "LibraryItemSyncJob")
    store.removeObject(forKey: "userSettingsHasQueuedJobs")

    return tasks
  }

  private func migrateSyncTasksFromUserDefaults(_ migration: RealmSwift.Migration) -> [MigrationObject] {
    let store = UserDefaults.standard

    guard
      let storedTasks = store.array(forKey: Constants.UserDefaults.syncTasksQueue) as? [Data],
      !storedTasks.isEmpty
    else { return [] }

    var tasks = [MigrationObject]()

    for taskData in storedTasks {
      autoreleasepool {
        if var taskParams = try? JSONSerialization.jsonObject(with: taskData) as? [String: Any],
           let taskId = taskParams["id"] as? String,
           let relativePath = taskParams["relativePath"] as? String,
           let jobTypeRaw = taskParams["jobType"] as? String,
           let jobType = SyncJobType(rawValue: jobTypeRaw) {

          if taskParams["lastPlayDateTimestamp"] is String {
            taskParams["lastPlayDateTimestamp"] = 0
          }

          let task = migrateTask(
            taskParams,
            id: taskId,
            relativePath: relativePath,
            jobType: jobType,
            migration: migration
          )
          tasks.append(task)
        }
      }
    }

    store.removeObject(forKey: Constants.UserDefaults.syncTasksQueue)

    return tasks
  }

  private func migrateTask(
    _ parameters: [String: Any],
    id: String,
    relativePath: String,
    jobType: SyncJobType,
    migration: RealmSwift.Migration
  ) -> MigrationObject {
    let className: String
    switch jobType {
    case .upload:
      className = "UploadTaskObject"
    case .update:
      className = "UpdateTaskObject"
    case .move:
      className = "MoveTaskObject"
    case .delete, .shallowDelete:
      className = "DeleteTaskObject"
    case .deleteBookmark:
      className = "DeleteBookmarkTaskObject"
    case .setBookmark:
      className = "SetBookmarkTaskObject"
    case .renameFolder:
      className = "RenameFolderTaskObject"
    case .uploadArtwork:
      className = "ArtworkUploadTaskObject"
    }

    migration.create(className, value: parameters)

    return migration.create(
      "SyncTaskReferenceObject",
      value: [
        "id": ObjectId.generate(),
        "taskID": id,
        "relativePath": relativePath,
        "jobType": jobType.rawValue
      ]
    )
  }
}
