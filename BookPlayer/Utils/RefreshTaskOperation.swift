//
//  RefreshTaskOperation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/2/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

/// Reference: https://www.avanderlee.com/swift/asynchronous-operations/
class RefreshTaskOperation: Operation {
  let syncService: SyncServiceProtocol
  private var syncTasksObserver: AnyCancellable?

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
    syncTasksObserver = syncService.observeTasksCount().sink { [weak self] count in
      guard let self else { return }

      if count == 0 {
        self.finish()
      }
    }
  }

  func finish() {
    syncTasksObserver = nil
    isExecuting = false
    isFinished = true
  }
}
