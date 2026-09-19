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

/// Keeps a background-refresh window open until the watched queue reports drained.
/// The POLICY (which lane counts) lives at the call site: `AppDelegate.handleAppRefresh`
/// waits on the `sync` lane only — provider pushes retry forever against an unreachable
/// home server and S3 uploads already run on a background URLSession, so neither should
/// hold the process awake.
///
/// Reference: https://www.avanderlee.com/swift/asynchronous-operations/
class RefreshTaskOperation: Operation {
  private let queueDrained: AnyPublisher<Bool, Never>
  private var drainObserver: AnyCancellable?

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

  /// `finish()` is reachable from the drain sink (main) and the expiration handler
  /// (a background queue); the KVO transition must happen exactly once.
  private var _hasFinished = false

  /// - Parameter queueDrained: `true` while nothing the caller cares about is queued.
  ///   A replaying publisher (e.g. `CurrentValueSubject`) finishes an already-idle
  ///   refresh immediately.
  init(queueDrained: AnyPublisher<Bool, Never>) {
    self.queueDrained = queueDrained
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
    drainObserver = queueDrained.sink { [weak self] drained in
      guard let self, drained else { return }

      self.finish()
    }
  }

  func finish() {
    let alreadyFinished: Bool = lockQueue.sync(flags: [.barrier]) {
      defer { _hasFinished = true }
      return _hasFinished
    }
    guard !alreadyFinished else { return }

    drainObserver = nil
    isExecuting = false
    isFinished = true
  }
}
