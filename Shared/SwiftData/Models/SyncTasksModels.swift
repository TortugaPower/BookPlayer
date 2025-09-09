//
//  SyncTasksModels.swift
//  BookPlayer
//
//  Created by Gianni Carlo on [Current Date].
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftData

/// SwiftData model that holds the ordered list of queued tasks
@Model
public class SyncTasksContainer {
  @Relationship(deleteRule: .cascade, inverse: \SyncTaskReferenceModel.container)
  public var tasks: [SyncTaskReferenceModel] = []

  public var orderedTasks: [SyncTaskReferenceModel] { tasks.sorted { $0.position < $1.position } }

  public init() {}
}

/// SwiftData model with type and task id reference to the real task
@Model
public class SyncTaskReferenceModel {
  @Attribute(.unique) public var id: String
  public var relativePath: String
  public var taskID: String
  public var jobType: SyncJobType
  public var position: Int

  public var container: SyncTasksContainer?

  public init(
    id: String = UUID().uuidString,
    relativePath: String,
    taskID: String,
    jobType: SyncJobType,
    position: Int
  ) {
    self.id = id
    self.relativePath = relativePath
    self.taskID = taskID
    self.jobType = jobType
    self.position = position
  }
}

@Model
public class UploadTaskModel {
  @Attribute(.unique) public var id: String
  public var relativePath: String
  public var originalFileName: String
  public var title: String
  public var details: String
  public var speed: Double?
  public var currentTime: Double
  public var duration: Double
  public var percentCompleted: Double
  public var isFinished: Bool
  public var orderRank: Int16
  public var lastPlayDateTimestamp: Double?
  public var type: Int16

  public init(
    id: String,
    relativePath: String,
    originalFileName: String,
    title: String,
    details: String,
    speed: Double? = nil,
    currentTime: Double,
    duration: Double,
    percentCompleted: Double,
    isFinished: Bool,
    orderRank: Int16,
    lastPlayDateTimestamp: Double? = nil,
    type: Int16
  ) {
    self.id = id
    self.relativePath = relativePath
    self.originalFileName = originalFileName
    self.title = title
    self.details = details
    self.speed = speed
    self.currentTime = currentTime
    self.duration = duration
    self.percentCompleted = percentCompleted
    self.isFinished = isFinished
    self.orderRank = orderRank
    self.lastPlayDateTimestamp = lastPlayDateTimestamp
    self.type = type
  }
}

@Model
public class UpdateTaskModel {
  @Attribute(.unique) public var id: String
  public var relativePath: String
  public var title: String?
  public var details: String?
  public var speed: Double?
  public var currentTime: Double?
  public var duration: Double?
  public var percentCompleted: Double?
  public var isFinished: Bool?
  public var orderRank: Int16?
  public var lastPlayDateTimestamp: Double?
  public var type: Int16?

  public init(
    id: String,
    relativePath: String,
    title: String? = nil,
    details: String? = nil,
    speed: Double? = nil,
    currentTime: Double? = nil,
    duration: Double? = nil,
    percentCompleted: Double? = nil,
    isFinished: Bool? = nil,
    orderRank: Int16? = nil,
    lastPlayDateTimestamp: Double? = nil,
    type: Int16? = nil
  ) {
    self.id = id
    self.relativePath = relativePath
    self.title = title
    self.details = details
    self.speed = speed
    self.currentTime = currentTime
    self.duration = duration
    self.percentCompleted = percentCompleted
    self.isFinished = isFinished
    self.orderRank = orderRank
    self.lastPlayDateTimestamp = lastPlayDateTimestamp
    self.type = type
  }
}

@Model
public class MoveTaskModel {
  @Attribute(.unique) public var id: String
  public var relativePath: String
  public var origin: String
  public var destination: String

  public init(id: String, relativePath: String, origin: String, destination: String) {
    self.id = id
    self.relativePath = relativePath
    self.origin = origin
    self.destination = destination
  }
}

@Model
public class DeleteTaskModel {
  @Attribute(.unique) public var id: String
  public var relativePath: String
  /// Can only be `delete` or `shallowDelete`
  public var jobType: SyncJobType

  public init(id: String, relativePath: String, jobType: SyncJobType) {
    self.id = id
    self.relativePath = relativePath
    self.jobType = jobType
  }
}

@Model
public class DeleteBookmarkTaskModel {
  @Attribute(.unique) public var id: String
  public var relativePath: String
  public var time: Double

  public init(id: String = UUID().uuidString, relativePath: String, time: Double) {
    self.id = id
    self.relativePath = relativePath
    self.time = time
  }
}

@Model
public class SetBookmarkTaskModel {
  @Attribute(.unique) public var id: String
  public var relativePath: String
  public var time: Double
  public var note: String?

  public init(id: String, relativePath: String, time: Double, note: String? = nil) {
    self.id = id
    self.relativePath = relativePath
    self.time = time
    self.note = note
  }
}

@Model
public class RenameFolderTaskModel {
  @Attribute(.unique) public var id: String
  public var relativePath: String
  public var name: String

  public init(id: String, relativePath: String, name: String) {
    self.id = id
    self.relativePath = relativePath
    self.name = name
  }
}

@Model
public class ArtworkUploadTaskModel {
  @Attribute(.unique) public var id: String
  public var relativePath: String

  public init(id: String, relativePath: String) {
    self.id = id
    self.relativePath = relativePath
  }
}
