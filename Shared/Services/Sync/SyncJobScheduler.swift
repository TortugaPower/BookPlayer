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
  var libraryFinishedSync: (() -> Void)? { get set }
  /// Uploads the metadata for the first time to the server
  func scheduleLibraryItemUploadJob(for item: SyncableItem)
  /// Update existing metadata in the server
  func scheduleMetadataUpdateJob(with relativePath: String, parameters: [String: Any])
  /// Cancel all stored and ongoing jobs
  func cancelAllJobs()
}

public class SyncJobScheduler: JobSchedulerProtocol, BPLogger {
  let libraryJobsPersister: UserDefaultsPersister
  var libraryQueueManager: SwiftQueueManager!
  public var libraryFinishedSync: (() -> Void)?

  public init() {
    self.libraryJobsPersister = UserDefaultsPersister(key: LibraryItemUploadJob.type)
    self.libraryQueueManager = SwiftQueueManagerBuilder(creator: LibraryItemUploadJobCreator())
      .set(persister: libraryJobsPersister)
      .set(listener: self)
      .build()
  }

  public func scheduleLibraryItemUploadJob(for item: SyncableItem) {
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

    JobBuilder(type: LibraryItemUploadJob.type)
      .singleInstance(forId: item.relativePath)
      .persist()
      .retry(limit: .unlimited)
      .internet(atLeast: .wifi)
      .with(params: parameters)
      .schedule(manager: libraryQueueManager)
  }

  /// Note: folder renames originalFilename property
  public func scheduleMetadataUpdateJob(with relativePath: String, parameters: [String: Any]) {
    JobBuilder(type: LibraryItemMetadataUpdateJob.type)
      .singleInstance(forId: relativePath, override: true)
      .persist()
      .retry(limit: .limited(3))
      .internet(atLeast: .wifi)
      .with(params: parameters)
      .schedule(manager: libraryQueueManager)
  }

  public func cancelAllJobs() {
    libraryQueueManager.cancelAllOperations()
    libraryJobsPersister.clearAll()
  }
}

extension SyncJobScheduler: JobListener {
  public func onJobScheduled(job: SwiftQueue.JobInfo) {
    Self.logger.trace("Schedule job for \(job.params["relativePath"] as? String)")
  }

  public func onBeforeRun(job: SwiftQueue.JobInfo) {}

  public func onAfterRun(job: SwiftQueue.JobInfo, result: SwiftQueue.JobCompletion) {}

  public func onTerminated(job: SwiftQueue.JobInfo, result: SwiftQueue.JobCompletion) {
    Self.logger.trace("Terminated job for \(job.params["relativePath"] as? String)")

    guard
      let pendingOperations = libraryQueueManager.getAll()["GLOBAL"],
      pendingOperations.isEmpty
    else { return }

    libraryFinishedSync?()
  }
}
