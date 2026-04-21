//
//  SyncOrchestrator.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 23/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import Combine

public protocol ConcurrenceServiceProtocol {
  var accessPolicy: [ExternalSyncJobType: Bool] { get set }
  
  init(maxConcurrentTasks: Int)
  
  func setup(libraryService: LibrarySyncProtocol)
  
  func observeConcurrentTasksCount() -> AnyPublisher<Int, Never>
  
  func getAllQueuedJobs() async -> [ConcurrentSyncTask]
  
  func getOrderedQueuedJobs(activeTasks: [String: TaskProgressTracker]) async -> [ConcurrentSyncTask]
  
  func scheduleMetadataUpdate(params: [String: Any])
  
  func scheduleFileUpload(params: [String: Any])
}

public class ConcurrenceService: ConcurrenceServiceProtocol {
  let operationQueue: OperationQueue
  var taskContainer: ConcurrentTasksRepositoryProtocol! // Your DB model
  var libraryService: LibrarySyncProtocol!
  
  public var accessPolicy: [ExternalSyncJobType: Bool] = [:]
  // Tracks which queueKeys currently have an active worker looping
  private var activeQueueKeys = Set<String>()
  private let stateLock = NSLock()
  private var disposeBag = Set<AnyCancellable>()
  private var listeningTask: Task<Void, Never>?
  public var tasksCountService: ConcurrentTasksCountService!
  // Services
  private let jellyfinService = JellyfinConnectionService()
  
  required public init(maxConcurrentTasks: Int = 4) {
    self.operationQueue = OperationQueue()
    self.operationQueue.name = "com.bookplayer.synctask.concurrent"
    // This still caps the total number of operations running simultaneously across all keys
    self.operationQueue.maxConcurrentOperationCount = maxConcurrentTasks
  }
  
  public func setup(libraryService: LibrarySyncProtocol) {
    self.libraryService = libraryService
    let tasksDataManager = TasksDataManager()
    self.taskContainer = ConcurrentTasksRepository(tasksDataManager: tasksDataManager)
    self.tasksCountService = ConcurrentTasksCountService(tasksDataManager: tasksDataManager)
    jellyfinService.setup()
    startListeningForNewTasks()
    bindObservers()
    wakeUpWorkers()
  }
  
  func bindObservers() {
    NotificationCenter.default.publisher(for: .logout, object: nil)
      .sink(receiveValue: { _ in
        UserDefaults.standard.set(
          false,
          forKey: Constants.UserDefaults.hasScheduledLibraryContents
        )
      })
      .store(in: &disposeBag)

    libraryService.progressUpdatePublisher.sink { [weak self] params in
      self?.scheduleMetadataUpdate(params: params)
    }
    .store(in: &disposeBag)
  }
  
  private func startListeningForNewTasks() {
    listeningTask = Task {
      let stream = NotificationCenter.default.notifications(named: .newTaskInQueue)
      
      for await notification in stream {
        guard let userInfo = notification.userInfo,
              let queueKey = userInfo["queueKey"] as? String else {
          continue
        }
        
        // Wake up the worker!
        await startWorkerLoop(for: queueKey)
      }
    }
  }
  
  /// Call this when the app wakes up, or when a new task is added to the database
  func wakeUpWorkers() {
    // Get all unique queue keys that currently have pending tasks
    Task {
      // Now you can safely await the actor!
      let pendingKeys = await taskContainer.getAllQueueKeys()
      
      for key in pendingKeys {
        await startWorkerLoop(for: key)
      }
    }
  }
  
  private func startWorkerLoop(for queueKey: String) async {
    // 1. Use scoped locking to check and update the state safely
    let isAlreadyRunning = stateLock.withLock {
      // This entire block is perfectly thread-safe and synchronous
      if activeQueueKeys.contains(queueKey) {
        return true
      } else {
        activeQueueKeys.insert(queueKey)
        return false
      }
    }
    
    // 2. If it was already running, safely bail out
    guard !isAlreadyRunning else { return }
    
    // 3. Now we are safely outside the lock, so we can await!
    await enqueueNextTask(for: queueKey)
  }
  
  public func observeConcurrentTasksCount() -> AnyPublisher<Int, Never> {
    return tasksCountService.observeConcurrentTasksCount()
  }
  
  private func enqueueNextTask(for queueKey: String) async {
    // 1. AWAIT the actor to safely fetch the next task
    guard let nextTask = await taskContainer.getNextTask(for: queueKey) else {
      // The queue is empty! Use scoped locking to remove the key.
      stateLock.withLock {
        activeQueueKeys.remove(queueKey)
      }
      return
    }
    guard let operation = createOperation(for: nextTask) else { return }

    operation.onProgress = { progress in
      Task { @MainActor in
        ConcurrentTaskProgressMonitor.shared.updateProgress(for: nextTask.id, progress: progress)
      }
    }
    
    operation.completionBlock = { [weak self] in
      // 2. Bridge back into the async world inside the synchronous completion block
      Task {
        guard let self = self else { return }
        
        if operation.didSucceed {
          await self.taskContainer.pop(nextTask)
        } else {
          try? await Task.sleep(for: .seconds(15))
          await self.taskContainer.pop(nextTask)
        }
        
        // 3. AWAIT the recursive call
        await MainActor.run {
          ConcurrentTaskProgressMonitor.shared.clear(taskID: nextTask.id)
        }
        await self.enqueueNextTask(for: queueKey)
      }
    }
    
    await MainActor.run {
      ConcurrentTaskProgressMonitor.shared.markAsProcessing(taskID: nextTask.id)
    }
    
    operationQueue.addOperation(operation)
  }
  
  public func getAllQueuedJobs() async -> [ConcurrentSyncTask] {
    return await taskContainer.getAllTasks()
  }
  
  public func getOrderedQueuedJobs(activeTasks: [String: TaskProgressTracker]) async -> [ConcurrentSyncTask] {
    return await taskContainer.getOrderedTasks(activeTasks: activeTasks)
  }
  
  private func createOperation(for task: ConcurrentSyncTask) -> AsyncOperation? {
    // Example generation
    switch task.jobType {
    case .update:
      guard let providerId = task.parameters["providerId"] as? String,
            let currentTime = task.parameters["currentTime"] as? Double,
            let percentCompleted = task.parameters["percentCompleted"] as? Double else {
        return nil
      }
      return JellyfinUpdateProgressOperation(providerItemId: providerId, positionTicks: Int(currentTime * 10_000_000), percentCompleted: percentCompleted, service: jellyfinService)
    case .uploadFile:
      guard let filePath = task.parameters["filePath"] as? String,
            let remotePath = task.parameters["remotePath"] as? String,
            let uuid = task.parameters["uuid"] as? String else {
        return nil
      }
      return FileUploadOperation(fileURL: URL(string: filePath)!, remoteURL: URL(string: remotePath)!, uuid: uuid)
    }
  }
}

extension ConcurrenceService {
  public func scheduleMetadataUpdate(params: [String: Any]) {
    guard accessPolicy[.update] == true else {
      return
    }
    
    Task {
      guard let queueKey = params["providerName"] as? String else {
        return
      }
      
      var params = params
      params["id"] = UUID().uuidString
      params["jobType"] = ExternalSyncJobType.update.rawValue
      params["queueKey"] = queueKey
      /// Override param `lastPlayDate` if it exists with the proper name
      if let lastPlayDate = params.removeValue(forKey: #keyPath(LibraryItem.lastPlayDate)) {
        params["lastPlayDateTimestamp"] = lastPlayDate
      }
      
      try await taskContainer.storeTask(parameters: params)
    }
  }
  
  public func scheduleFileUpload(params: [String: Any]) {
    guard accessPolicy[.uploadFile] == true else {
      return
    }
    
    Task {
      let queueKey = "uploadFile"
      var params = params
      params["id"] = UUID().uuidString
      params["jobType"] = ExternalSyncJobType.uploadFile.rawValue
      params["queueKey"] = queueKey
      
      try await taskContainer.storeTask(parameters: params)
    }
  }
}
