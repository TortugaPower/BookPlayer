//
//  SyncJobScheduler.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/8/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation
import CoreData
import SwiftData

public protocol JobSchedulerProtocol {
  /// Last sync error information for debugging
  var lastSyncError: SyncErrorInfo? { get }

  func queuedJobsCount() async -> Int
  /// Uploads the metadata for the first time to the server
  func scheduleLibraryItemUploadJob(for item: SyncableItem) async
  /// Update existing metadata in the server
  func scheduleMetadataUpdateJob(with relativePath: String, parameters: [String: Any]) async
  
  func scheduleMatchUuidsJob(uuidsDict: [String: String]) async
  /// Move item to destination
  func scheduleMoveItemJob(with itemOrigin: PathUuidPair, to parentFolder: PathUuidPair?) async
  /// Delete item
  func scheduleDeleteJob(with relativePath: String, mode: DeleteMode, for uuid: String) async
  /// Create or update a bookmark
  func scheduleSetBookmarkJob(
    with relativePath: String,
    time: Double,
    note: String?,
    for uuid: String
  ) async
  /// Delete a bookmark
  func scheduleDeleteBookmarkJob(with relativePath: String, time: Double, for uuid: String) async
  /// Rename a folder
  func scheduleRenameFolderJob(with relativePath: String, name: String, for uuid: String) async
  /// Upload current cached artwork
  func scheduleArtworkUpload(with relativePath: String, for uuid: String) async
  /// Get all queued jobs
  func getAllQueuedJobs() async -> [SyncTaskReference]
  /// Get all queued jobs with full parameters
  func getAllQueuedJobsWithParams() async -> [SyncTask]
  /// Cancel all stored and ongoing jobs
  func cancelAllJobs()
  /// Cancel all stored and ongoing jobs and wait for completion
  func resetAllJobs() async
  /// Check if there's an upload task queued for the item
  func hasUploadTask(for relativePath: String) async -> Bool
}

public class SyncJobScheduler: JobSchedulerProtocol, BPLogger {
  let networkClient: NetworkClientProtocol
  let operationQueue: OperationQueue
  let tasksDataManager: TasksDataManager
  let dataManager: DataManager
  
  /// Reference for observer
  private var syncTasksObserver: NSKeyValueObservation?
  private var disposeBag = Set<AnyCancellable>()
  private let lockQueue = DispatchQueue(label: "com.bookplayer.synctask.schedule")
  /// Reference to ongoing library fetch task
  private var initializeStoreTask: Task<(), Error>?
  private var taskStore: SyncTasksStorage!
  private var tasksProgress: [String: Double] = [:]
  /// Last sync error information for debugging
  public private(set) var lastSyncError: SyncErrorInfo?
  
  public init(
    tasksDataManager: TasksDataManager,
    networkClient: NetworkClientProtocol = NetworkClient(),
    operationQueue: OperationQueue = OperationQueue(),
    dataManager: DataManager
  ) {
    operationQueue.maxConcurrentOperationCount = 1
    self.operationQueue = operationQueue
    self.networkClient = networkClient
    self.tasksDataManager = tasksDataManager
    self.dataManager = dataManager
    
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
    
    NotificationCenter.default.publisher(for: .uploadProgressUpdated)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] notification in
        guard
          let uuid = notification.userInfo?["uuid"] as? String,
          let relativePath = notification.userInfo?["relativePath"] as? String,
          let progress = notification.userInfo?["progress"] as? Double
        else { return }
        let key = SyncProgressKey.resolve(uuid: uuid, relativePath: relativePath)
        self?.updateProgress(for: key, value: progress)
      }
      .store(in: &disposeBag)
    
    initializeStore()
  }
  
  private func initializeStore() {
    initializeStoreTask = Task.detached {
      do {
        self.taskStore = try SyncTasksStorage(tasksDataManager: self.tasksDataManager)
      } catch {
        fatalError("Failed to initialize sync tasks store: \(error.localizedDescription)")
      }
      
      /// This will start the loop where it will periodically check for queued tasks to execute
      self.queueNextTask()
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
      "uuid": item.uuid,
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
      "jobType": SyncJobType.upload.rawValue,
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
  
  public func scheduleMoveItemJob(with itemOrigin: PathUuidPair, to parentFolder: PathUuidPair?) async {
    let useUuids = Constants.isRealUuid(itemOrigin.uuid)

    let parameters: [String: Any] = [
      "id": UUID().uuidString,
      "relativePath": itemOrigin.relativePath,
      "origin": useUuids ? itemOrigin.uuid : itemOrigin.relativePath,
      "destination": useUuids ? (parentFolder?.uuid ?? "") : (parentFolder?.relativePath ?? ""),
      "jobType": SyncJobType.move.rawValue,
      "uuid": itemOrigin.uuid
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
  
  public func scheduleMatchUuidsJob(uuidsDict: [String: String]) async {
    guard !uuidsDict.isEmpty else { return }
    
    let parameters: [String: Any] = [
      "jobType": SyncJobType.matchUuid.rawValue,
      "id": UUID().uuidString,
      "relativePath": "",
      "uuid": "",
      "uuids": uuidsDict
    ]
    await persistTask(parameters: parameters)
  }
  
  public func scheduleDeleteJob(with relativePath: String, mode: DeleteMode, for uuid: String) async {
    let jobType: SyncJobType
    
    switch mode {
    case .deep:
      jobType = SyncJobType.delete
    case .shallow:
      jobType = SyncJobType.shallowDelete
    }
    
    let parameters: [String: Any] = [
      "id": UUID().uuidString,
      "uuid": uuid,
      "relativePath": relativePath,
      "jobType": jobType.rawValue,
    ]
        
    await persistTask(parameters: parameters)
  }
  
  public func scheduleDeleteBookmarkJob(with relativePath: String, time: Double, for uuid: String) async {
    let parameters: [String: Any] = [
      "id": UUID().uuidString,
      "uuid": uuid,
      "relativePath": relativePath,
      "time": time,
      "jobType": SyncJobType.deleteBookmark.rawValue,
    ]
      
    await persistTask(parameters: parameters)
  }
  
  public func scheduleSetBookmarkJob(
    with relativePath: String,
    time: Double,
    note: String?,
    for uuid: String
  ) async {
    var params: [String: Any] = [
      "id": UUID().uuidString,
      "uuid": uuid,
      "relativePath": relativePath,
      "time": time,
      "jobType": SyncJobType.setBookmark.rawValue,
    ]
    
    if let note {
      params["note"] = note
    }
        
    await persistTask(parameters: params)
  }
  
  public func scheduleRenameFolderJob(with relativePath: String, name: String, for uuid: String) async {
    let params: [String: Any] = [
      "id": UUID().uuidString,
      "uuid": uuid,
      "relativePath": relativePath,
      "name": name,
      "jobType": SyncJobType.renameFolder.rawValue,
    ]
        
    await persistTask(parameters: params)
  }
  
  public func scheduleArtworkUpload(with relativePath: String, for uuid: String) async {
    let params: [String: Any] = [
      "id": UUID().uuidString,
      "uuid": uuid,
      "relativePath": relativePath,
      "jobType": SyncJobType.uploadArtwork.rawValue,
    ]
    
    await persistTask(parameters: params)
  }
  
  public func getAllQueuedJobs() async -> [SyncTaskReference] {
    _ = await initializeStoreTask?.result
    let currentProgress = await MainActor.run { tasksProgress }
    return await taskStore.getAllTasks(progress: currentProgress)
  }
  
  public func getAllQueuedJobsWithParams() async -> [SyncTask] {
    _ = await initializeStoreTask?.result
    return await taskStore.getAllTasksWithParams()
  }
  
  public func cancelAllJobs() {
    Task {
      _ = await initializeStoreTask?.result
      try await taskStore.clearAll()
      operationQueue.cancelAllOperations()
      await MainActor.run {
        tasksProgress.removeAll()
      }
    }
  }
  
  public func resetAllJobs() async {
    _ = await initializeStoreTask?.result
    try? await taskStore.clearAll()
    operationQueue.cancelAllOperations()
    await MainActor.run {
      tasksProgress.removeAll()
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
      Self.logger.error("Failed to persist task \(error): \(parameters.description)")
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
        
        operationTask.completionBlock = { [weak self, unowned operationTask] in
          guard let self else {
            return
          }
          let error = operationTask.error
          let results = operationTask.results

          if let error {
            Self.logger.error("Operation failed: \(error.localizedDescription)")
            self.lastSyncError = SyncErrorInfo(
              taskId: task.id,
              uuid: task.uuid,
              jobType: task.jobType,
              error: error.localizedDescription
            )
            self.retryQueuedTask()
          } else {
            Task { [weak self] in
              guard let self else { return }
              if let results {
                switch results {
                case .matchUuid(let response):
                  await self.handleMatchUuidsResponse(response)
                }
              }
              self.handleFinishedTask(task)
            }
          }
        }
        
        operationQueue.addOperation(operationTask)
      } catch {
        Self.logger.error("\(error.localizedDescription)")
      }
    }
  }
  
  private func updateProgress(
    for key: String,
    value: Double
  ) {
    tasksProgress[key] = value
  }
  
  private func retryQueuedTask() {
    /// Retry in 5 seconds
    lockQueue.asyncAfter(deadline: .now() + .seconds(5)) {
      self.queueNextTask()
    }
  }
  
  private func handleFinishedTask(_ task: SyncTask) {
    lockQueue.asyncAfter(deadline: .now() + .seconds(1)) {
      Task { @MainActor in
        _ = await self.initializeStoreTask?.result
        try! await self.taskStore.finishedTask(id: task.id, jobType: task.jobType)
        self.queueNextTask()
        self.tasksProgress.removeValue(forKey: task.progressKey)
      }
    }
  }
  
  private func handleMatchUuidsResponse(_ results: MatchUuidsResponse) async {
    guard !results.conflicts.isEmpty else { return }
    do {
      try await applyCoreDataConflicts(results.conflicts)
      try await taskStore.applyMatchUuidConflicts(results.conflicts)
    } catch {
      Self.logger.error("Failed to apply matchUuid conflicts: \(error.localizedDescription)")
      self.lastSyncError = SyncErrorInfo(
        taskId: "",
        uuid: "",
        jobType: .matchUuid,
        error: error.localizedDescription
      )
    }
  }

  private func applyCoreDataConflicts(_ conflicts: [ItemConflict]) async throws {
    let context = dataManager.getBackgroundContext()
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      context.perform {
        do {
          let oldUuids = conflicts.map { $0.key }
          let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
          fetchRequest.predicate = NSPredicate(format: "uuid IN %@", oldUuids)
          let items = try context.fetch(fetchRequest)
          let uuidMap = Dictionary(uniqueKeysWithValues: conflicts.map { ($0.key, $0.uuid) })
          for item in items {
            if let newUuid = uuidMap[item.uuid] {
              item.uuid = newUuid
            }
          }
          try context.save()
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
