//
//  ConcurrentSyncTask.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 24/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

/// Pending-task count for one queue key
public struct QueueSummary: Identifiable {
  public let queueKey: String
  public let count: Int

  public var id: String { queueKey }

  public init(queueKey: String, count: Int) {
    self.queueKey = queueKey
    self.count = count
  }
}

public struct ConcurrentSyncTask: Identifiable {
  public let id: String
  public let queueKey: String
  public let jobType: SyncJobType
  public let uuid: String
  public let relativePath: String
  public let parameters: [String: Any]

  public init(
    id: String,
    queueKey: String,
    jobType: SyncJobType,
    parameters: [String: Any],
    uuid: String = "",
    relativePath: String = ""
  ) {
    self.id = id
    self.queueKey = queueKey
    self.jobType = jobType
    self.parameters = parameters
    self.uuid = uuid
    self.relativePath = relativePath
  }
}
