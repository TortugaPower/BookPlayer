//
//  HardcoverProgressOperation.swift
//  BookPlayer
//
//  Created by Pedro Iniguez on 11/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Sends a book's progress to Hardcover. The app's `HardcoverService` implements it: the
/// Hardcover client and its sign-in live in the app, and the queue that runs it lives here
public protocol HardcoverProgressSyncing: AnyObject {
  /// Sends the book's progress, with the Currently Reading status first when Hardcover doesn't
  /// have it yet (the status starts the read the progress goes on). Returns when it's sent or
  /// when there's nothing to send; throws only a failure worth retrying (no connection, a
  /// timeout, a busy or failing server), which the queue retries with backoff
  func syncProgress(uuid: String, relativePath: String, percentCompleted: Double) async throws
}

/// Where the app queues Hardcover progress: `SyncQueueService`'s Hardcover lane
public protocol HardcoverProgressQueueing: AnyObject {
  /// Queues the book's progress. A task of the same Hardcover book still waiting takes the new
  /// percentage instead, so an offline session ends up as one request
  func scheduleHardcoverProgress(uuid: String, relativePath: String, hardcoverBookId: Int, percentCompleted: Double)

  /// Drops every queued Hardcover task, for an unlink or another account
  func clearHardcoverProgress() async
}

/// Runs one queued Hardcover progress task through the app's `HardcoverProgressSyncing`. A failure
/// leaves the task queued: the lane backs off and runs it again
final class HardcoverProgressOperation: AsyncOperation, BPLogger, @unchecked Sendable {
  let uuid: String
  let relativePath: String
  let percentCompleted: Double
  /// Strong for the run: the service keeps only a weak reference
  private let syncer: HardcoverProgressSyncing?

  init(uuid: String, relativePath: String, percentCompleted: Double, syncer: HardcoverProgressSyncing?) {
    self.uuid = uuid
    self.relativePath = relativePath
    self.percentCompleted = percentCompleted
    self.syncer = syncer
    super.init()
  }

  override func main() {
    guard !isCancelled else {
      finish()
      return
    }

    Task { [weak self] in
      guard let self else { return }
      defer { self.finish() }

      /// The app wires the service in once its services exist; a task popped before that waits
      guard let syncer = self.syncer else {
        Self.logger.info("Hardcover progress waits: the app hasn't wired Hardcover in yet")
        return
      }

      do {
        try await syncer.syncProgress(
          uuid: self.uuid,
          relativePath: self.relativePath,
          percentCompleted: self.percentCompleted
        )
        self.didSucceed = true
      } catch {
        Self.logger.error("Hardcover progress will be retried: \(error)")
      }
    }
  }
}
