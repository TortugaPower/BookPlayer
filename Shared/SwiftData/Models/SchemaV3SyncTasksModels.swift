//
//  SchemaV3SyncTasksModels.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 20/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftData
import Foundation

// MARK: - Schema V1 (The Container)
public enum SchemaV3: VersionedSchema {
  public static var versionIdentifier = Schema.Version(2, 0, 0)
  
  // List EVERY model in your app here
  public static var models: [any PersistentModel.Type] {
    [
      SyncTasksContainer.self,
      SyncTaskReferenceModel.self,
      UploadTaskModel.self,
      UpdateTaskModel.self,
      MoveTaskModel.self,
      DeleteTaskModel.self,
      DeleteBookmarkTaskModel.self,
      SetBookmarkTaskModel.self,
      RenameFolderTaskModel.self,
      ArtworkUploadTaskModel.self,
      MatchUuidsTaskModel.self,
      UploadExternalResourceTaskModel.self,
      ConcurrentTasksContainer.self,
      ConcurrentTaskReferenceModel.self,
      ExternalUpdateTaskModel.self,
      ConcurrentUploadTaskModel.self,
      ExternalResourceToDownloadTaskModel.self
    ]
  }
  
  // Paste your exact models inside the enum
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
    public var uuid: String = UUID().uuidString
    
    public var container: SyncTasksContainer?
    
    public init(
      id: String = UUID().uuidString,
      uuid: String,
      relativePath: String,
      taskID: String,
      jobType: SyncJobType,
      position: Int
    ) {
      self.id = id
      self.uuid = uuid
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
    public var orderRank: Int
    public var lastPlayDateTimestamp: Double?
    public var type: Int16
    public var uuid: String = UUID().uuidString
    public var provider: String? = nil

    public init(
      id: String,
      uuid: String,
      relativePath: String,
      originalFileName: String,
      title: String,
      details: String,
      speed: Float? = nil,
      currentTime: Double,
      duration: Double,
      percentCompleted: Double,
      isFinished: Bool,
      orderRank: Int,
      lastPlayDateTimestamp: Double? = nil,
      type: Int16,
      provider: String? = nil
    ) {
      self.id = id
      self.uuid = uuid
      self.relativePath = relativePath
      self.originalFileName = originalFileName
      self.title = title
      self.details = details
      if let speed {
        self.speed = Double(speed)
      } else {
        self.speed = nil
      }
      self.currentTime = currentTime
      self.duration = duration
      self.percentCompleted = percentCompleted
      self.isFinished = isFinished
      self.orderRank = orderRank
      self.lastPlayDateTimestamp = lastPlayDateTimestamp
      self.type = type
      self.provider = provider
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
    public var uuid: String = UUID().uuidString
    
    public init(
      id: String,
      uuid: String,
      relativePath: String,
      title: String? = nil,
      details: String? = nil,
      speed: Float? = nil,
      currentTime: Double? = nil,
      duration: Double? = nil,
      percentCompleted: Double? = nil,
      isFinished: Bool? = nil,
      orderRank: Int16? = nil,
      lastPlayDateTimestamp: Double? = nil,
      type: Int16? = nil
    ) {
      self.id = id
      self.uuid = uuid
      self.relativePath = relativePath
      self.title = title
      self.details = details
      if let speed {
        self.speed = Double(speed)
      } else {
        self.speed = nil
      }
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
    public var uuid: String = UUID().uuidString
    
    public init(id: String, uuid: String, relativePath: String, origin: String, destination: String) {
      self.id = id
      self.uuid = uuid
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
    public var uuid: String = UUID().uuidString
    
    public init(id: String, uuid: String, relativePath: String, jobType: SyncJobType) {
      self.id = id
      self.uuid = uuid
      self.relativePath = relativePath
      self.jobType = jobType
    }
  }
  
  @Model
  public class DeleteBookmarkTaskModel {
    @Attribute(.unique) public var id: String
    public var relativePath: String
    public var time: Double
    public var uuid: String = UUID().uuidString
    
    public init(id: String = UUID().uuidString, uuid: String, relativePath: String, time: Double) {
      self.id = id
      self.uuid = uuid
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
    public var uuid: String = UUID().uuidString
    
    public init(id: String, uuid: String, relativePath: String, time: Double, note: String? = nil) {
      self.id = id
      self.uuid = uuid
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
    public var uuid: String = UUID().uuidString
    
    public init(id: String, uuid: String, relativePath: String, name: String) {
      self.id = id
      self.uuid = uuid
      self.relativePath = relativePath
      self.name = name
    }
  }
  
  @Model
  public class ArtworkUploadTaskModel {
    @Attribute(.unique) public var id: String
    public var relativePath: String
    public var uuid: String = UUID().uuidString
    
    public init(id: String, uuid: String, relativePath: String) {
      self.id = id
      self.uuid = uuid
      self.relativePath = relativePath
    }
  }
  
  @Model
  public class MatchUuidsTaskModel {
    @Attribute(.unique) public var id: String
    public var uuids: [String: String]
    
    public init(id: String, uuids: [String: String]) {
      self.id = id
      self.uuids = uuids
    }
  }
  
  @Model
  public class UploadExternalResourceTaskModel {
    @Attribute(.unique) public var id: String
    public var providerId: String
    public var providerName: String
    public var lastSyncedAt: Date?
    public var syncStatus: String
    public var processedFile: Bool
    public var uuid: String
    
    public init(
      id: String,
      uuid: String,
      providerId: String,
      providerName: String,
      lastSyncedAt: Date?,
      syncStatus: String,
      processedFile: Bool
    ) {
      self.id = id
      self.uuid = uuid
      self.providerId = providerId
      self.providerName = providerName
      self.lastSyncedAt = lastSyncedAt
      self.syncStatus = syncStatus
      self.processedFile = processedFile
    }
  }
  
  // Paste your exact models inside the enum
  @Model
  public class ConcurrentTasksContainer {
    @Relationship(deleteRule: .cascade, inverse: \ConcurrentTaskReferenceModel.container)
    public var tasks: [ConcurrentTaskReferenceModel] = []
    
    public var orderedTasks: [ConcurrentTaskReferenceModel] { tasks.sorted { $0.position < $1.position } }
    
    public var allQueueKeys: [String] {
      Array(Set(tasks.map { $0.queueKey }))
    }
    
    public init() {}
  }
  
  @Model
  public class ConcurrentTaskReferenceModel {
    @Attribute(.unique) public var id: String
    public var taskID: String
    public var jobType: ExternalSyncJobType
    public var position: Int
    public var queueKey: String
    public var container: ConcurrentTasksContainer?

    public init(
      id: String = UUID().uuidString,
      queueKey: String,
      taskID: String,
      jobType: ExternalSyncJobType,
      position: Int
    ) {
      self.id = id
      self.taskID = taskID
      self.jobType = jobType
      self.queueKey = queueKey
      self.position = position
    }
  }
  
  @Model
  public class ExternalUpdateTaskModel {
    @Attribute(.unique) public var id: String
    public var title: String?
    public var details: String?
    public var currentTime: Double?
    public var percentCompleted: Double?
    public var isFinished: Bool?
    public var lastPlayDateTimestamp: Double?
    public var providerName: String
    public var providerId: String
    
    public init(
      id: String,
      providerName: String,
      providerId: String,
      title: String? = nil,
      details: String? = nil,
      currentTime: Double? = nil,
      percentCompleted: Double? = nil,
      isFinished: Bool? = nil,
      lastPlayDateTimestamp: Double? = nil,
    ) {
      self.id = id
      self.providerName = providerName
      self.providerId = providerId
      self.title = title
      self.details = details
      self.currentTime = currentTime
      self.percentCompleted = percentCompleted
      self.isFinished = isFinished
      self.lastPlayDateTimestamp = lastPlayDateTimestamp
    }
  }
  
  @Model
  public class ConcurrentUploadTaskModel {
    @Attribute(.unique) public var id: String
    public var filePath: String
    public var remotePath: String?
    public var uuid: String
    
    public init(
      id: String,
      uuid: String,
      filePath: String,
      remotePath: String? = nil
    ) {
      self.id = id
      self.uuid = uuid
      self.filePath = filePath
      self.remotePath = remotePath
    }
  }
  
  @Model
  public class ExternalResourceToDownloadTaskModel {
    @Attribute(.unique) public var id: String
    public var uuid: String
    public var uploaded: Bool
    
    public init(
      id: String,
      uuid: String,
      uploaded: Bool
    ) {
      self.id = id
      self.uuid = uuid
      self.uploaded = uploaded
    }
  }
}
