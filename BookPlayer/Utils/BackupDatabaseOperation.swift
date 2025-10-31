//
//  BackupDatabaseOperation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

/// Operation that performs database backup as an asynchronous background task
/// Reference: https://www.avanderlee.com/swift/asynchronous-operations/
class BackupDatabaseOperation: Operation {

  // MARK: - Properties

  private let backupService = DatabaseBackupService()

  private let lockQueue = DispatchQueue(
    label: "com.bookplayer.asyncoperation.databasebackup",
    attributes: .concurrent
  )

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

  // MARK: - Operation Lifecycle

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
    Task {
      // Perform the backup operation
      await backupService.performBackup()

      // Mark operation as complete
      finish()
    }
  }

  func finish() {
    isExecuting = false
    isFinished = true
  }
}
