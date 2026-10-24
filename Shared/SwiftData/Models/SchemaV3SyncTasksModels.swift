//
//  SchemaV3SyncTasksModels.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 20/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftData
import Foundation

// MARK: - Schema V3 (The Container)
public enum SchemaV3: VersionedSchema {
  public static var versionIdentifier = Schema.Version(3, 0, 0)
  
  // List EVERY model in your app here
  public static var models: [any PersistentModel.Type] {
    [
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
      SyncQueueContainer.self,
      QueuedTaskReferenceModel.self,
      ExternalUpdateTaskModel.self,
      UploadFileTaskModel.self,
      ExternalResourceToDownloadTaskModel.self,
      DeleteExternalResourceTaskModel.self
    ]
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
    public var hostId: String?
    public var uuid: String
    
    public init(
      id: String,
      uuid: String,
      providerId: String,
      providerName: String,
      lastSyncedAt: Date?,
      syncStatus: String,
      processedFile: Bool,
      hostId: String? = nil
    ) {
      self.id = id
      self.uuid = uuid
      self.providerId = providerId
      self.providerName = providerName
      self.lastSyncedAt = lastSyncedAt
      self.syncStatus = syncStatus
      self.processedFile = processedFile
      self.hostId = hostId
    }
  }
  
  /// Single container for every queued task, sharded by `queueKey`.
  /// The `"sync"` key holds the serial BookPlayer-server queue; every other key
  /// is a provider/upload queue that runs concurrently with the rest.
  @Model
  public class SyncQueueContainer {
    @Relationship(deleteRule: .cascade, inverse: \QueuedTaskReferenceModel.container)
    public var tasks: [QueuedTaskReferenceModel] = []

    public var orderedTasks: [QueuedTaskReferenceModel] { tasks.sorted { $0.position < $1.position } }

    public var allQueueKeys: [String] {
      Array(Set(tasks.map { $0.queueKey }))
    }

    public func orderedTasks(for queueKey: String) -> [QueuedTaskReferenceModel] {
      tasks
        .filter { $0.queueKey == queueKey }
        .sorted { $0.position < $1.position }
    }

    public init() {}
  }

  @Model
  public class QueuedTaskReferenceModel {
    @Attribute(.unique) public var id: String
    public var taskID: String
    public var jobType: SyncJobType
    public var position: Int
    public var queueKey: String
    public var uuid: String = ""
    public var relativePath: String = ""
    public var container: SyncQueueContainer?
    /// Parking: set when the server answered with a coded error the task can never get
    /// past as sent (`TaskPauseScope` raw value); nil = pending. The rest describes it.
    public var pauseScope: String?
    public var errorCode: String?
    public var errorMessage: String?
    public var httpStatus: Int?
    public var pausedAt: Date?
    /// The Sentry event reporting this pause, so a re-park (launch retry, Retry) doesn't
    /// report it again; kept across resumes
    public var sentryEventId: String?

    public init(
      id: String = UUID().uuidString,
      queueKey: String,
      taskID: String,
      jobType: SyncJobType,
      position: Int,
      uuid: String = "",
      relativePath: String = ""
    ) {
      self.id = id
      self.taskID = taskID
      self.jobType = jobType
      self.queueKey = queueKey
      self.position = position
      self.uuid = uuid
      self.relativePath = relativePath
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
    /// The stable host identity of the server this push belongs to. Without persisting it,
    /// a reloaded task resolves no connection and the push is (correctly) discarded — i.e.
    /// dropping this field silently discards EVERY persisted progress push.
    public var hostId: String?
    
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
      hostId: String? = nil,
    ) {
      self.id = id
      self.providerName = providerName
      self.providerId = providerId
      self.hostId = hostId
      self.title = title
      self.details = details
      self.currentTime = currentTime
      self.percentCompleted = percentCompleted
      self.isFinished = isFinished
      self.lastPlayDateTimestamp = lastPlayDateTimestamp
    }
  }
  
  @Model
  public class UploadFileTaskModel {
    @Attribute(.unique) public var id: String
    public var filePath: String
    public var uuid: String
    /// The open multipart upload (nil until `start` answers). With it, the upload resumes
    /// from S3's part list; `start` again would abort it.
    public var uploadId: String?
    /// Fixed for the life of `uploadId`: every part but the last is exactly this size
    public var partSize: Int = 0
    /// The file's size when the upload started; `complete` must match it
    public var fileSize: Int64 = 0
    /// Fresh starts after S3 lost or rejected the upload (`upload_not_found`,
    /// `invalid_parts`); past the budget the task parks
    public var restartCount: Int = 0

    public init(
      id: String,
      uuid: String,
      filePath: String,
      uploadId: String? = nil,
      partSize: Int = 0,
      fileSize: Int64 = 0,
      restartCount: Int = 0
    ) {
      self.id = id
      self.uuid = uuid
      self.filePath = filePath
      self.uploadId = uploadId
      self.partSize = partSize
      self.fileSize = fileSize
      self.restartCount = restartCount
    }
  }
  
  @Model
  public class ExternalResourceToDownloadTaskModel {
    @Attribute(.unique) public var id: String
    public var uuid: String

    public init(
      id: String,
      uuid: String
    ) {
      self.id = id
      self.uuid = uuid
    }
  }

  @Model
  public class DeleteExternalResourceTaskModel {
    @Attribute(.unique) public var id: String
    public var uuid: String
    public var relativePath: String
    public var providerName: String
    public var providerId: String

    public init(
      id: String,
      uuid: String,
      relativePath: String,
      providerName: String,
      providerId: String
    ) {
      self.id = id
      self.uuid = uuid
      self.relativePath = relativePath
      self.providerName = providerName
      self.providerId = providerId
    }
  }
}
