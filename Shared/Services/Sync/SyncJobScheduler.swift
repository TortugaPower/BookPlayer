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
  func scheduleFileUploadJob(for relativePath: String, remoteUrlPath: String)
  func scheduleMetadataUploadJob(for item: LibraryItem)
}

public class SyncJobScheduler: JobSchedulerProtocol {
  let metadataQueueManager: SwiftQueueManager
  let fileUploadQueueManager: SwiftQueueManager
//  let folderQueueManager: SwiftQueueManager
//  let progressQueueManager: SwiftQueueManager

  public init() {
    self.metadataQueueManager = SwiftQueueManagerBuilder(creator: LibraryItemMetadataUploadJobCreator())
      .set(persister: UserDefaultsPersister(key: LibraryItemMetadataUploadJob.type))
      .build()
    self.fileUploadQueueManager = SwiftQueueManagerBuilder(creator: LibraryItemFileUploadJobCreator())
      .set(persister: UserDefaultsPersister(key: LibraryItemFileUploadJob.type))
      .build()
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

  public func scheduleMetadataUploadJob(for item: LibraryItem) {
    let relativePath = item.relativePath!
    var parameters: [String: Any] = [
      "relativePath": relativePath,
      "originalFileName": item.originalFileName!,
      "title": item.title!,
      "details": item.details!,
      "speed": item.speed,
      "currentTime": item.currentTime,
      "duration": item.duration,
      "percentCompleted": item.percentCompleted,
      "isFinished": item.isFinished,
      "orderRank": item.orderRank,
      "type": item.getItemType()
    ]

    if let lastPlayTimestamp = item.lastPlayDate?.timeIntervalSince1970 {
      parameters["lastPlayDateTimestamp"] = lastPlayTimestamp
    }

    JobBuilder(type: LibraryItemMetadataUploadJob.type)
      .singleInstance(forId: relativePath)
      .persist()
      .retry(limit: .limited(3))
      .internet(atLeast: .wifi)
      .with(params: parameters)
      .schedule(manager: metadataQueueManager)
  }
}
