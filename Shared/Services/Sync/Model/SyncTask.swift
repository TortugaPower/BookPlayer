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

  public init(id: String, relativePath: String, jobType: SyncJobType, parameters: [String: Any]) {
    self.id = id
    self.relativePath = relativePath
    self.jobType = jobType
    self.parameters = parameters
  }
}

public struct SyncTaskReference: Identifiable {
  public let id: String
  public let relativePath: String
  public let jobType: SyncJobType

  public init(id: String, relativePath: String, jobType: SyncJobType) {
    self.id = id
    self.relativePath = relativePath
    self.jobType = jobType
  }
}

/// Information about the last sync error for debugging purposes
public struct SyncErrorInfo {
  public let taskId: String
  public let relativePath: String
  public let jobType: SyncJobType
  public let error: String
  public let timestamp: Date

  public init(
    taskId: String,
    relativePath: String,
    jobType: SyncJobType,
    error: String,
    timestamp: Date = Date()
  ) {
    self.taskId = taskId
    self.relativePath = relativePath
    self.jobType = jobType
    self.error = error
    self.timestamp = timestamp
  }
}
