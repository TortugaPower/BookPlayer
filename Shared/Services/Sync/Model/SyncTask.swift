//
//  SyncTask.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SyncTask: Identifiable {
  public let id: String
  public let relativePath: String
  public let jobType: SyncJobType
  public let parameters: [String: Any]
  public let uuid: String

  public init(id: String, uuid: String, relativePath: String, jobType: SyncJobType, parameters: [String: Any]) {
    self.id = id
    self.jobType = jobType
    self.parameters = parameters
    self.uuid = uuid
    self.relativePath = relativePath
  }
}

public struct SyncTaskReference: Identifiable {
  public let id: String
  public let uuid: String
  public let relativePath: String
  public let jobType: SyncJobType
  public let progress: Double

  public init(id: String, uuid: String, relativePath: String, jobType: SyncJobType, progress: Double) {
    self.id = id
    self.uuid = uuid
    self.relativePath = relativePath
    self.jobType = jobType
    self.progress = progress
  }
}

/// Information about the last sync error for debugging purposes
public struct SyncErrorInfo {
  public let taskId: String
  public let uuid: String
  public let jobType: SyncJobType
  public let error: String
  public let timestamp: Date

  public init(
    taskId: String,
    uuid: String,
    jobType: SyncJobType,
    error: String,
    timestamp: Date = Date()
  ) {
    self.taskId = taskId
    self.uuid = uuid
    self.jobType = jobType
    self.error = error
    self.timestamp = timestamp
  }
}
