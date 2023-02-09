//
//  SyncJobScheduler.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/8/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import SwiftQueue

public protocol JobSchedulerProtocol {
  /// Uploads the file to the server
  func scheduleFileUploadJob(for relativePath: String, remoteUrlPath: String)
  /// Uploads the metadata for the first time to the server
  func scheduleMetadataUploadJob(for item: SyncableItem)
  /// Update existing metadata in the server
  func scheduleMetadataUpdateJob(with relativePath: String, parameters: [String: Any])
  /// Cancel all stored and ongoing jobs
  func cancelAllJobs()
}

public class SyncJobScheduler: JobSchedulerProtocol {
  let metadataQueueManager: SwiftQueueManager
  let fileUploadQueueManager: SwiftQueueManager
  let metadataJobsPersister: UserDefaultsPersister
  let fileUploadJobsPersister: UserDefaultsPersister

  public init() {
    let metadataJobsPersister = UserDefaultsPersister(key: LibraryItemMetadataUploadJob.type)
    self.metadataQueueManager = SwiftQueueManagerBuilder(creator: LibraryItemMetadataUploadJobCreator())
      .set(persister: metadataJobsPersister)
      .build()
    self.metadataJobsPersister = metadataJobsPersister

    let fileUploadJobsPersister = UserDefaultsPersister(key: LibraryItemFileUploadJob.type)
    self.fileUploadQueueManager = SwiftQueueManagerBuilder(creator: LibraryItemFileUploadJobCreator())
      .set(persister: fileUploadJobsPersister)
      .build()
    self.fileUploadJobsPersister = fileUploadJobsPersister
  }

  public func scheduleFileUploadJob(for relativePath: String, remoteUrlPath: String) {
    JobBuilder(type: LibraryItemFileUploadJob.type)
      .singleInstance(forId: relativePath)
      .persist()
      .retry(limit: .limited(3))
      .internet(atLeast: .wifi)
      .with(params: [
        "relativePath": relativePath,
        "remoteUrlPath": remoteUrlPath
      ])
      .schedule(manager: fileUploadQueueManager)
  }

  public func scheduleMetadataUploadJob(for item: SyncableItem) {
    var parameters: [String: Any] = [
      "relativePath": item.relativePath,
      "originalFileName": item.originalFileName,
      "title": item.title,
      "details": item.details,
      "currentTime": item.currentTime,
      "duration": item.duration,
      "percentCompleted": item.percentCompleted,
      "isFinished": item.isFinished,
      "orderRank": item.orderRank,
      "type": item.type.rawValue
    ]

    if let lastPlayTimestamp = item.lastPlayDateTimestamp {
      parameters["lastPlayDateTimestamp"] = Int(lastPlayTimestamp)
    } else {
      parameters["lastPlayDateTimestamp"] = nil
    }

    if let speed = item.speed {
      parameters["speed"] = speed
    }

    JobBuilder(type: LibraryItemMetadataUploadJob.type)
      .singleInstance(forId: item.relativePath)
      .persist()
      .retry(limit: .limited(3))
      .internet(atLeast: .wifi)
      .with(params: parameters)
      .schedule(manager: metadataQueueManager)
  }

  /// Note: folder renames originalFilename property
  public func scheduleMetadataUpdateJob(with relativePath: String, parameters: [String: Any]) {
    JobBuilder(type: LibraryItemMetadataUploadJob.type)
      .singleInstance(forId: relativePath, override: true)
      .persist()
      .retry(limit: .limited(3))
      .internet(atLeast: .wifi)
      .with(params: parameters)
      .schedule(manager: metadataQueueManager)
  }

  public func cancelAllJobs() {
    metadataQueueManager.cancelAllOperations()
    metadataJobsPersister.clearAll()
    fileUploadQueueManager.cancelAllOperations()
    fileUploadJobsPersister.clearAll()
  }
}
