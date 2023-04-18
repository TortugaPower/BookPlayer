//
//  SyncJobScheduler.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/8/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Combine
import Foundation
import SwiftQueue

public protocol JobSchedulerProtocol {
  var libraryFinishedSync: (() -> Void)? { get set }
  /// Uploads the metadata for the first time to the server
  func scheduleLibraryItemUploadJob(for item: SyncableItem)
  /// Update existing metadata in the server
  func scheduleMetadataUpdateJob(with relativePath: String, parameters: [String: Any])
  /// Move item to destination
  func scheduleMoveItemJob(with relativePath: String, to parentFolder: String?)
  /// Delete item
  func scheduleDeleteJob(with relativePath: String, mode: DeleteMode)
  /// Cancel all stored and ongoing jobs
  func cancelAllJobs()
}

public class SyncJobScheduler: JobSchedulerProtocol, BPLogger {
  let libraryJobsPersister: UserDefaultsPersister
  var libraryQueueManager: SwiftQueueManager!
  public var libraryFinishedSync: (() -> Void)?
  private var disposeBag = Set<AnyCancellable>()

  public init() {
    self.libraryJobsPersister = UserDefaultsPersister(key: LibraryItemSyncJob.type)

    recreateQueue()
    bindObservers()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .uploadCompleted)
      .sink { [weak self] notification in
        guard
          let task = notification.object as? URLSessionTask,
          let path = task.taskDescription
        else { return }

        self?.libraryQueueManager.cancelOperations(uuid: path)
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .recreateQueue, object: nil)
      .sink { [weak self] _ in
        self?.recreateQueue()
      }
      .store(in: &disposeBag)
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
      "type": item.type.rawValue,
      "jobType": JobType.upload.rawValue
    ]

    if let lastPlayTimestamp = item.lastPlayDateTimestamp {
      parameters["lastPlayDateTimestamp"] = Int(lastPlayTimestamp)
    } else {
      parameters["lastPlayDateTimestamp"] = nil
    }

    if let speed = item.speed {
      parameters["speed"] = speed
    }

    JobBuilder(type: LibraryItemSyncJob.type)
      .singleInstance(forId: "\(JobType.upload.identifier)/\(item.relativePath)")
      .persist()
      .retry(limit: .unlimited)
      .internet(atLeast: .wifi)
      .with(params: parameters)
      .schedule(manager: libraryQueueManager)
  }

  public func scheduleMoveItemJob(with relativePath: String, to parentFolder: String?) {
    JobBuilder(type: LibraryItemSyncJob.type)
      .singleInstance(forId: "\(JobType.move.identifier)/\(relativePath)")
      .persist()
      .retry(limit: .unlimited)
      .internet(atLeast: .wifi)
      .with(params: [
        "origin": relativePath,
        "destination": parentFolder ?? "",
        "jobType": JobType.move.rawValue
      ])
      .schedule(manager: libraryQueueManager)
  }

  /// Note: folder renames originalFilename property
  public func scheduleMetadataUpdateJob(with relativePath: String, parameters: [String: Any]) {
    var parameters = parameters
    parameters["jobType"] = JobType.update.rawValue

    JobBuilder(type: LibraryItemSyncJob.type)
      .singleInstance(forId: "\(JobType.update.identifier)/\(relativePath)", override: true)
      .persist()
      .retry(limit: .limited(3))
      .internet(atLeast: .wifi)
      .with(params: parameters)
      .schedule(manager: libraryQueueManager)
  }

  public func scheduleDeleteJob(with relativePath: String, mode: DeleteMode) {
    let jobType: JobType

    switch mode {
    case .deep:
      jobType = JobType.delete
    case .shallow:
      jobType = JobType.shallowDelete
    }

    JobBuilder(type: LibraryItemSyncJob.type)
      .singleInstance(forId: "\(jobType.identifier)/\(relativePath)")
      .persist()
      .retry(limit: .limited(3))
      .internet(atLeast: .wifi)
      .with(params: [
        "relativePath": relativePath,
        "jobType": jobType.rawValue
      ])
      .schedule(manager: libraryQueueManager)
  }

  public func cancelAllJobs() {
    libraryQueueManager.cancelAllOperations()
    libraryJobsPersister.clearAll()
  }

  public func recreateQueue() {
    /// Suspend queue if it's already created
    if libraryQueueManager != nil {
      libraryQueueManager.isSuspended = true
    }

    libraryQueueManager = SwiftQueueManagerBuilder(creator: LibraryItemUploadJobCreator())
      .set(persister: libraryJobsPersister)
      .set(listener: self)
      .build()
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
