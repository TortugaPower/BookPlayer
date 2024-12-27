//
//  SyncTasksObject.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 20/2/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import RealmSwift

/// Model that holds the ordered list of queued tasks
class SyncTasksObject: Object {
  @Persisted var tasks = List<SyncTaskReferenceObject>()
}

/// Object with type and task id reference to the real task
class SyncTaskReferenceObject: Object {
  @Persisted(primaryKey: true) var id: ObjectId
  @Persisted var relativePath: String
  @Persisted var taskID: String
  @Persisted var jobType: SyncJobType
}

class UploadTaskObject: Object {
  @Persisted(primaryKey: true) var id: String
  @Persisted var relativePath: String
  @Persisted var originalFileName: String
  @Persisted var title: String
  @Persisted var details: String
  @Persisted var speed: Double?
  @Persisted var currentTime: Double
  @Persisted var duration: Double
  @Persisted var percentCompleted: Double
  @Persisted var isFinished: Bool
  @Persisted var orderRank: Int
  @Persisted var lastPlayDateTimestamp: Double?
  @Persisted var type: Int16
}

class UpdateTaskObject: Object {
  @Persisted(primaryKey: true) var id: String
  @Persisted var relativePath: String
  @Persisted var title: String?
  @Persisted var details: String?
  @Persisted var speed: Double?
  @Persisted var currentTime: Double?
  @Persisted var duration: Double?
  @Persisted var percentCompleted: Double?
  @Persisted var isFinished: Bool?
  @Persisted var orderRank: Int?
  @Persisted var lastPlayDateTimestamp: Double?
  @Persisted var type: Int16?
}

class MoveTaskObject: Object {
  @Persisted(primaryKey: true) var id: String
  @Persisted var relativePath: String
  @Persisted var origin: String
  @Persisted var destination: String
}

class DeleteTaskObject: Object {
  @Persisted(primaryKey: true) var id: String
  @Persisted var relativePath: String
  /// Can only be `delete` or `shallowDelete`
  @Persisted var jobType: SyncJobType
}

class DeleteBookmarkTaskObject: Object {
  @Persisted(primaryKey: true) var id: String
  @Persisted var relativePath: String
  @Persisted var time: Double
}

class SetBookmarkTaskObject: Object {
  @Persisted(primaryKey: true) var id: String
  @Persisted var relativePath: String
  @Persisted var time: Double
  @Persisted var note: String?
}

class RenameFolderTaskObject: Object {
  @Persisted(primaryKey: true) var id: String
  @Persisted var relativePath: String
  @Persisted var name: String
}

class ArtworkUploadTaskObject: Object {
  @Persisted(primaryKey: true) var id: String
  @Persisted var relativePath: String
}
