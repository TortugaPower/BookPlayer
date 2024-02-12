//
//  RefreshTaskOperation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/2/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

/// Reference: https://www.avanderlee.com/swift/asynchronous-operations/
class RefreshTaskOperation: Operation {
  /// Sync service
  let syncService: SyncServiceProtocol
  private var syncTasksObserver: NSKeyValueObservation?

  private let lockQueue = DispatchQueue(label: "com.bookplayer.asyncoperation.refreshtask", attributes: .concurrent)
  override var isAsynchronous: Bool { true }

  private var _isExecuting: Bool = false
  override private(set) var isExecuting: Bool {
    get {
      return lockQueue.sync { () -> Bool in
        return _isExecuting
      }
    }
    set {
      willChangeValue(forKey: "isExecuting")
      lockQueue.sync(flags: [.barrier]) {
        _isExecuting = newValue
      }
      didChangeValue(forKey: "isExecuting")
    }
  }

  private var _isFinished: Bool = false
  override private(set) var isFinished: Bool {
    get {
      return lockQueue.sync { () -> Bool in
        return _isFinished
      }
    }
    set {
      willChangeValue(forKey: "isFinished")
      lockQueue.sync(flags: [.barrier]) {
        _isFinished = newValue
      }
      didChangeValue(forKey: "isFinished")
    }
  }

  init(syncService: SyncServiceProtocol) {
    self.syncService = syncService
  }

  override func start() {
    guard !isCancelled else {
      finish()
      return
    }

    isFinished = false
    isExecuting = true
    main()
  }

  override func main() {
    syncTasksObserver = UserDefaults.standard.observe(
      \.userSyncTasksQueue,
       options: [.initial, .new]
    ) { [weak self] _, _ in
      guard let self else { return }
      
      Task {
        if await self.syncService.queuedJobsCount() == 0 {
          self.finish()
        }
      }
    }
  }

  func finish() {
    syncTasksObserver = nil
    isExecuting = false
    isFinished = true
  }
}
