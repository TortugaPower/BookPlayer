//
//  SyncJobScheduler.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/8/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation

public protocol JobSchedulerProtocol {

  func queuedJobsCount() async -> Int
  /// Uploads the metadata for the first time to the server
  func scheduleLibraryItemUploadJob(for item: SyncableItem) async
  /// Update existing metadata in the server
  func scheduleMetadataUpdateJob(with relativePath: String, parameters: [String: Any]) async
  /// Move item to destination
  func scheduleMoveItemJob(with relativePath: String, to parentFolder: String?) async
  /// Delete item
  func scheduleDeleteJob(with relativePath: String, mode: DeleteMode) async
  /// Create or update a bookmark
  func scheduleSetBookmarkJob(
    with relativePath: String,
    time: Double,
    note: String?
  ) async
  /// Delete a bookmark
  func scheduleDeleteBookmarkJob(with relativePath: String, time: Double) async
  /// Rename a folder
  func scheduleRenameFolderJob(with relativePath: String, name: String) async
  /// Upload current cached artwork
  func scheduleArtworkUpload(with relativePath: String) async
  /// Get all queued jobs
  func getAllQueuedJobs() async -> [SyncTaskReference]
  /// Cancel all stored and ongoing jobs
  func cancelAllJobs()
  /// Check if there's an upload task queued for the item
  func hasUploadTask(for relativePath: String) async -> Bool
}

public class SyncJobScheduler: JobSchedulerProtocol, BPLogger {
  let networkClient: NetworkClientProtocol
  let operationQueue: OperationQueue

  /// Reference for observer
  private var syncTasksObserver: NSKeyValueObservation?
  private var disposeBag = Set<AnyCancellable>()
  private let lockQueue = DispatchQueue(label: "com.bookplayer.synctask.schedule")
  /// Reference to ongoing library fetch task
  private var initializeStoreTask: Task<(), Error>?
  private var taskStore: SyncTasksStorage!

  public init(
    networkClient: NetworkClientProtocol = NetworkClient(),
    operationQueue: OperationQueue = OperationQueue()
  ) {
    operationQueue.maxConcurrentOperationCount = 1
    self.operationQueue = operationQueue
    self.networkClient = networkClient

    bindObservers()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .uploadCompleted)
      .sink { notification in
        guard
          let task = notification.object as? URLSessionTask,
          let relativePath = task.taskDescription
        else { return }

        do {
          let hardLinkURL = FileManager.default.temporaryDirectory.appendingPathComponent(relativePath)
          try FileManager.default.removeItem(at: hardLinkURL)
        } catch {
          Self.logger.warning("Failed to delete hard link for \(relativePath): \(error.localizedDescription)")
        }
      }
      .store(in: &disposeBag)

    initializeStore()
  }

  private func initializeStore() {
    initializeStoreTask = Task {
      do {
        taskStore = try await SyncTasksStorage()
      } catch {
        fatalError("Failed to initialize sync tasks store: \(error.localizedDescription)")
      }

      /// This will start the loop where it will periodically check for queued tasks to execute
      queueNextTask()
    }
  }

  private func createHardLink(for item: SyncableItem) {
    let hardLinkURL = FileManager.default.temporaryDirectory.appendingPathComponent(item.relativePath)

    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(item.relativePath)

    /// Clean up in case hard link path is already used
    if FileManager.default.fileExists(atPath: hardLinkURL.path) {
      try? FileManager.default.removeItem(at: hardLinkURL)
    }

    /// Don't throw and let the rest of the items queue up
    try? FileManager.default.linkItem(at: fileURL, to: hardLinkURL)
  }

  public func scheduleLibraryItemUploadJob(for item: SyncableItem) async {
    /// Create hard link to file location in case the user moves the item around in the library
    createHardLink(for: item)

    var parameters: [String: Any] = [
      "id": UUID().uuidString,
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
      "jobType": SyncJobType.upload.rawValue
    ]

    if let lastPlayTimestamp = item.lastPlayDateTimestamp {
      parameters["lastPlayDateTimestamp"] = Int(lastPlayTimestamp)
    } else {
      parameters["lastPlayDateTimestamp"] = nil
    }

    if let speed = item.speed {
      parameters["speed"] = speed
    }

    await persistTask(parameters: parameters)
  }

  public func scheduleMoveItemJob(with relativePath: String, to parentFolder: String?) async {
    let parameters: [String: Any] = [
      "id": UUID().uuidString,
      "relativePath": relativePath,
      "origin": relativePath,
      "destination": parentFolder ?? "",
      "jobType": SyncJobType.move.rawValue
    ]

    await persistTask(parameters: parameters)
  }

  /// Note: folder renames originalFilename property
  public func scheduleMetadataUpdateJob(with relativePath: String, parameters: [String: Any]) async {
    var parameters = parameters
    parameters["jobType"] = SyncJobType.update.rawValue
    parameters["id"] = UUID().uuidString

    await persistTask(parameters: parameters)
  }

  public func scheduleDeleteJob(with relativePath: String, mode: DeleteMode) async {
    let jobType: SyncJobType

    switch mode {
    case .deep:
      jobType = SyncJobType.delete
    case .shallow:
      jobType = SyncJobType.shallowDelete
    }
    
    let parameters: [String: Any] = [
      "id": UUID().uuidString,
      "relativePath": relativePath,
      "jobType": jobType.rawValue
    ]

    await persistTask(parameters: parameters)
  }

  public func scheduleDeleteBookmarkJob(with relativePath: String, time: Double) async {
    let parameters: [String: Any] = [
      "id": UUID().uuidString,
      "relativePath": relativePath,
      "time": time,
      "jobType": SyncJobType.deleteBookmark.rawValue
    ]

    await persistTask(parameters: parameters)
  }

  public func scheduleSetBookmarkJob(
    with relativePath: String,
    time: Double,
    note: String?
  ) async {
    var params: [String: Any] = [
      "id": UUID().uuidString,
      "relativePath": relativePath,
      "time": time,
      "jobType": SyncJobType.setBookmark.rawValue
    ]

    if let note {
      params["note"] = note
    }

    await persistTask(parameters: params)
  }

  public func scheduleRenameFolderJob(with relativePath: String, name: String) async {
    let params: [String: Any] = [
      "id": UUID().uuidString,
      "relativePath": relativePath,
      "name": name,
      "jobType": SyncJobType.renameFolder.rawValue
    ]

    await persistTask(parameters: params)
  }

  public func scheduleArtworkUpload(with relativePath: String) async {
    let params: [String: Any] = [
      "id": UUID().uuidString,
      "relativePath": relativePath,
      "jobType": SyncJobType.uploadArtwork.rawValue
    ]

    await persistTask(parameters: params)
  }

  public func getAllQueuedJobs() async -> [SyncTaskReference] {
    _ = await initializeStoreTask?.result
    return await taskStore.getAllTasks()
  }

  public func cancelAllJobs() {
    Task {
      _ = await initializeStoreTask?.result
      try await taskStore.clearAll()
      operationQueue.cancelAllOperations()
    }
  }

  public func queuedJobsCount() async -> Int {
    _ = await initializeStoreTask?.result
    return await taskStore.getTasksCount()
  }

  private func persistTask(parameters: [String: Any]) async {
    do {
      _ = await initializeStoreTask?.result
      try await taskStore.appendTask(parameters: parameters)
    } catch {
      Self.logger.error("Failed to persist task")
    }
  }

  /// Check if there's an upload task queued for the item
  public func hasUploadTask(for relativePath: String) async -> Bool {
    return await taskStore.hasUploadTask(for: relativePath)
  }

  private func queueNextTask() {
    Task {
      _ = await initializeStoreTask?.result

      do {
        guard
          let task = try await self.taskStore.getNextTask()
        else {
          self.retryQueuedTask()
          return
        }

        let operationTask = LibraryItemSyncOperation(
          client: networkClient,
          task: task
        )

        operationTask.completionBlock = { [unowned self, unowned operationTask] in
          if let error = operationTask.error {
            Self.logger.error("Operation failed: \(error.localizedDescription)")
            self.retryQueuedTask()
          } else {
            self.handleFinishedTask(id: task.id)
          }
        }

        operationQueue.addOperation(operationTask)
      } catch {
        Self.logger.error("\(error.localizedDescription)")
      }
    }
  }

  private func retryQueuedTask() {
    /// Retry in 5 seconds
    lockQueue.asyncAfter(deadline: .now() + .seconds(5)) {
      self.queueNextTask()
    }
  }

  private func handleFinishedTask(id: String) {
    lockQueue.asyncAfter(deadline: .now() + .seconds(1)) {
      Task {
        _ = await self.initializeStoreTask?.result
        try! await self.taskStore.finishedTask(id: id)
        self.queueNextTask()
      }
    }
  }
}
