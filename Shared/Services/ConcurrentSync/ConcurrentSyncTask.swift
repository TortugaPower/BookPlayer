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

  /// The key `.uploadProgressUpdated` carries for this item — what a row matches on
  public var progressKey: String {
    SyncProgressKey.resolve(uuid: uuid, relativePath: relativePath)
  }
}
