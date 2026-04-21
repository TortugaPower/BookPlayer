//
//  SyncTask.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Resolves the stable key used to track upload progress and match UI rows.
/// Falls back to `relativePath` when `uuid` is empty or a known migration placeholder —
/// those collide across legacy-migrated items until `matchUuid` backfills real uuids.
public enum SyncProgressKey {
  public static func resolve(uuid: String, relativePath: String) -> String {
    guard !uuid.isEmpty,
          uuid != Constants.uuidPlaceholder,
          uuid != Constants.legacyUuidPlaceholder
    else { return relativePath }
    return uuid
  }
}

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

  public var progressKey: String {
    SyncProgressKey.resolve(uuid: uuid, relativePath: relativePath)
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

  public var progressKey: String {
    SyncProgressKey.resolve(uuid: uuid, relativePath: relativePath)
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
