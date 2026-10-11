//
//  RefreshTaskOperationTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// First coverage for the background-refresh keep-alive: it must hold the window open
/// exactly until the watched queue reports drained, and never finish twice.
final class RefreshTaskOperationTests: XCTestCase {
  func testFinishesImmediatelyWhenAlreadyDrained() {
    let drained = CurrentValueSubject<Bool, Never>(true)
    let operation = RefreshTaskOperation(queueDrained: drained.eraseToAnyPublisher())

    operation.start()

    XCTAssertTrue(operation.isFinished)
    XCTAssertFalse(operation.isExecuting)
  }

  func testStaysAliveUntilDrained() {
    let drained = CurrentValueSubject<Bool, Never>(false)
    let operation = RefreshTaskOperation(queueDrained: drained.eraseToAnyPublisher())

    operation.start()
    XCTAssertTrue(operation.isExecuting)
    XCTAssertFalse(operation.isFinished)

    drained.send(false)
    XCTAssertFalse(operation.isFinished, "a non-drained emission must not end the window")

    drained.send(true)
    XCTAssertTrue(operation.isFinished)
    XCTAssertFalse(operation.isExecuting)
  }

  func testCancelledBeforeStartFinishesWithoutSubscribing() {
    let drained = PassthroughSubject<Bool, Never>()
    let operation = RefreshTaskOperation(queueDrained: drained.eraseToAnyPublisher())

    operation.cancel()
    operation.start()

    XCTAssertTrue(operation.isFinished)
  }

  /// The expiration handler calls finish() after cancel(); a late emission must not flip
  /// the KVO state a second time.
  func testFinishIsIdempotent() {
    let drained = CurrentValueSubject<Bool, Never>(false)
    let operation = RefreshTaskOperation(queueDrained: drained.eraseToAnyPublisher())
    operation.start()

    var finishedTransitions = 0
    let observer = operation.observe(\.isFinished, options: [.new]) { _, _ in
      finishedTransitions += 1
    }
    defer { observer.invalidate() }

    operation.cancel()
    operation.finish()
    operation.finish()
    drained.send(true)

    XCTAssertTrue(operation.isFinished)
    XCTAssertEqual(finishedTransitions, 1)
  }

  /// The policy the AppDelegate wires: a drained sync lane ends the window even while
  /// uploads and provider pushes are still queued.
  func testSyncLanePolicy_ignoresOtherLanes() {
    let counts = CurrentValueSubject<QueueCounts, Never>(
      QueueCounts(byQueueKey: [TaskQueueKey.uploadFile: 3, "jellyfin": 1, TaskQueueKey.sync: 1])
    )
    let operation = RefreshTaskOperation(queueDrained: counts.laneDrained(TaskQueueKey.sync))

    operation.start()
    XCTAssertFalse(operation.isFinished)

    counts.send(QueueCounts(byQueueKey: [TaskQueueKey.uploadFile: 3, "jellyfin": 1]))
    XCTAssertTrue(operation.isFinished)
  }
}
