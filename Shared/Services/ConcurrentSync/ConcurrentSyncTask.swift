//
//  ConcurrentSyncTask.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 24/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

public struct ConcurrentSyncTask: Identifiable {
  public let id: String
  public let queueKey: String
  public let jobType: ExternalSyncJobType
  public let parameters: [String: Any]

  public init(id: String, queueKey: String, jobType: ExternalSyncJobType, parameters: [String: Any]) {
    self.id = id
    self.queueKey = queueKey
    self.jobType = jobType
    self.parameters = parameters
  }
}
