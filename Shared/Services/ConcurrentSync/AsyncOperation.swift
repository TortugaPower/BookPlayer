//
//  AsyncOperation.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 23/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

class AsyncOperation: Operation, @unchecked Sendable {
  enum State: String {
    case ready, executing, finished
    fileprivate var keyPath: String { return "is\(rawValue.capitalized)" }
  }
  
  /// `state` is read by the OperationQueue and written from both the queue thread (`start()`)
  /// and the subclasses' detached Tasks (`finish()`), so access is lock-guarded — the classic
  /// async-Operation footgun. KVO notifications fire outside the lock.
  private let stateLock = NSLock()
  private var _state = State.ready
  var state: State {
    get {
      stateLock.lock(); defer { stateLock.unlock() }
      return _state
    }
    set {
      let oldValue: State
      stateLock.lock()
      oldValue = _state
      stateLock.unlock()
      willChangeValue(forKey: newValue.keyPath)
      willChangeValue(forKey: oldValue.keyPath)
      stateLock.lock()
      _state = newValue
      stateLock.unlock()
      didChangeValue(forKey: oldValue.keyPath)
      didChangeValue(forKey: newValue.keyPath)
    }
  }
  
  var onProgress: (@Sendable (Double) -> Void)?
  /// Written from the subclasses' async Tasks / completion sinks, read from the queue
  /// thread in ConcurrenceService's completionBlock — lock-guarded like `state` so the
  /// read has a happens-before edge with the write.
  private var _didSucceed = false
  var didSucceed: Bool {
    get {
      stateLock.lock(); defer { stateLock.unlock() }
      return _didSucceed
    }
    set {
      stateLock.lock(); defer { stateLock.unlock() }
      _didSucceed = newValue
    }
  }
  override var isReady: Bool { super.isReady && state == .ready }
  override var isExecuting: Bool { state == .executing }
  override var isFinished: Bool { state == .finished }
  override var isAsynchronous: Bool { true }
  
  override func start() {
    guard !isCancelled else {
      // Route through finish() so didFinish is set — writing state directly would
      // let a later stray finish() fire the isFinished KVO pair a second time
      finish()
      return
    }
    state = .executing
    main()
  }
  
  // Subclasses must call this when their async work is totally done.
  // Idempotent: cancel() and a racing terminal completion callback can BOTH reach here
  // (Combine won't interrupt a sink already mid-execution), and the isFinished KVO pair
  // must fire exactly once per operation or the OperationQueue misbehaves.
  private var didFinish = false
  func finish() {
    stateLock.lock()
    if didFinish {
      stateLock.unlock()
      return
    }
    didFinish = true
    stateLock.unlock()
    state = .finished
  }
}
