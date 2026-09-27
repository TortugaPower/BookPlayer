//
//  BackgroundSessionWakeTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import UIKit
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// iOS's handler for a background session is called once, and for uploads only after they
/// settle (calling it earlier suspends the app mid-request)
@MainActor
final class BackgroundSessionWakeTests: XCTestCase {
  private var settleCalls = 0
  private var downloadSettleCalls = 0
  private var settleRelease: CheckedContinuation<Void, Never>?
  private var began = 0
  private var ended = 0
  private var coordinator: BackgroundSessionWakeCoordinator!

  private func makeCoordinator(
    settles: Bool = true,
    timeout: Duration = .seconds(5),
    staleEventsAfter: TimeInterval = 60
  ) {
    coordinator = BackgroundSessionWakeCoordinator(dependencies: .init(
      activateSessions: { _ in },
      settleUploads: { [unowned self] in
        self.settleCalls += 1
        guard !settles else { return }
        await withCheckedContinuation { self.settleRelease = $0 }
      },
      settleDownloads: { [unowned self] in self.downloadSettleCalls += 1 },
      beginBackgroundTask: { [unowned self] _ in
        self.began += 1
        return UIBackgroundTaskIdentifier(rawValue: 42)
      },
      endBackgroundTask: { [unowned self] _ in self.ended += 1 },
      timeout: timeout,
      staleEventsAfter: staleEventsAfter
    ))
  }

  private func finishEvents(_ identifier: String) {
    NotificationCenter.default.post(name: .backgroundSessionFinishedEvents, object: identifier)
  }

  private func waitUntil(_ timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline, !condition() {
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  override func tearDown() {
    settleRelease?.resume()
    settleRelease = nil
    coordinator = nil
    super.tearDown()
  }

  func testUploadWake_answersAfterTheUploadsSettle() async throws {
    makeCoordinator()
    var calls = 0
    coordinator.handleEvents(forSession: BackgroundTransferSessions.uploadIdentifier) { calls += 1 }
    XCTAssertEqual(calls, 0, "not before the session's events are in")

    finishEvents(BackgroundTransferSessions.uploadIdentifier)

    try await waitUntil { calls == 1 }
    XCTAssertEqual(calls, 1)
    XCTAssertEqual(settleCalls, 1)
    XCTAssertEqual(began, 1)
    XCTAssertEqual(ended, 1, "the background task ends with the wake")
  }

  /// The spike saw iOS hand the handler over after the events were already delivered
  func testUploadWake_eventsFinishedBeforeTheHandler() async throws {
    makeCoordinator()
    finishEvents(BackgroundTransferSessions.cellularUploadIdentifier)
    var calls = 0

    coordinator.handleEvents(forSession: BackgroundTransferSessions.cellularUploadIdentifier) { calls += 1 }

    try await waitUntil { calls == 1 }
    XCTAssertEqual(calls, 1)
    XCTAssertEqual(settleCalls, 1)
  }

  /// A stuck upload mustn't keep iOS waiting: the timeout answers, once
  func testUploadWake_timesOutWhenTheUploadsNeverSettle() async throws {
    makeCoordinator(settles: false, timeout: .milliseconds(100))
    var calls = 0
    coordinator.handleEvents(forSession: BackgroundTransferSessions.uploadIdentifier) { calls += 1 }
    finishEvents(BackgroundTransferSessions.uploadIdentifier)

    try await waitUntil { calls == 1 }
    settleRelease?.resume()
    settleRelease = nil
    try await Task.sleep(for: .milliseconds(200))

    XCTAssertEqual(calls, 1, "settling late doesn't call the handler again")
    XCTAssertEqual(ended, 1)
  }

  /// The finished downloads' follow-up (chapters, verification, scheduling) runs after their
  /// delegate callbacks: the wake waits for it too
  func testDownloadWake_answersOnceTheDownloadsSettle() async throws {
    makeCoordinator()
    var calls = 0
    coordinator.handleEvents(forSession: BackgroundTransferSessions.downloadIdentifier) { calls += 1 }
    XCTAssertEqual(calls, 0)

    finishEvents(BackgroundTransferSessions.downloadIdentifier)

    try await waitUntil { calls == 1 }
    XCTAssertEqual(calls, 1)
    XCTAssertEqual(downloadSettleCalls, 1)
    XCTAssertEqual(settleCalls, 0, "downloads have no parts to top up")
    XCTAssertEqual(ended, 1)
  }

  /// A new wake for the same session answers the one it replaces instead of dropping it
  func testSecondWake_forTheSameSession_answersTheFirst() {
    makeCoordinator()
    var first = 0
    var second = 0
    coordinator.handleEvents(forSession: BackgroundTransferSessions.uploadIdentifier) { first += 1 }

    coordinator.handleEvents(forSession: BackgroundTransferSessions.uploadIdentifier) { second += 1 }

    XCTAssertEqual(first, 1)
    XCTAssertEqual(second, 0)
  }

  /// Events that finished long before belong to an earlier wake: the new one still waits
  func testStaleFinishedEvents_doNotAnswerALaterWake() async throws {
    makeCoordinator(timeout: .milliseconds(300), staleEventsAfter: 0.05)
    finishEvents(BackgroundTransferSessions.downloadIdentifier)
    try await Task.sleep(for: .milliseconds(100))
    var calls = 0

    coordinator.handleEvents(forSession: BackgroundTransferSessions.downloadIdentifier) { calls += 1 }

    XCTAssertEqual(downloadSettleCalls, 0, "not answered from the stale record")
    try await waitUntil { calls == 1 }
    XCTAssertEqual(calls, 1, "the fallback still answers")
  }

  /// A session nothing resumes in the background (e.g. the single-file downloads)
  func testUnknownSession_isAnsweredRightAway() {
    makeCoordinator()
    var calls = 0

    coordinator.handleEvents(forSession: "SingleFileDownloadService") { calls += 1 }

    XCTAssertEqual(calls, 1)
  }

  /// The session never reports back in this launch: iOS is still answered
  func testWake_withoutEvents_isAnsweredByTheFallback() async throws {
    makeCoordinator(timeout: .milliseconds(100))
    var calls = 0

    coordinator.handleEvents(forSession: BackgroundTransferSessions.downloadIdentifier) { calls += 1 }

    try await waitUntil { calls == 1 }
    XCTAssertEqual(calls, 1)
  }
}
