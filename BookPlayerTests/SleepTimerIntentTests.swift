//
//  SleepTimerIntentTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// Siri and Shortcuts call an intent's `perform()` from the cooperative pool. Off the main actor, the
/// sleep timer's publishers fired there, and the player's turned-on handler wrote its sleep bookmark to
/// Core Data's view context from a background thread (BOOKPLAYER-128M, BOOKPLAYER-12QZ)
final class SleepTimerIntentTests: XCTestCase {
  private var disposeBag = Set<AnyCancellable>()
  /// Whether each sleep timer event fired on the main thread
  private var eventsOnMain = [Bool]()

  override func setUp() {
    super.setUp()
    SleepTimer.shared.$state
      .dropFirst()
      .sink { [weak self] _ in self?.eventsOnMain.append(Thread.isMainThread) }
      .store(in: &disposeBag)
    SleepTimer.shared.timerTurnedOnPublisher
      .sink { [weak self] _ in self?.eventsOnMain.append(Thread.isMainThread) }
      .store(in: &disposeBag)
  }

  override func tearDown() {
    disposeBag.removeAll()
    SleepTimer.shared.setTimer(.off)
    super.tearDown()
  }

  func testCustomSleepTimerIntentSetsTheTimerOnMain() async throws {
    XCTAssertFalse(isMainThread(), "the test calls perform() off main, as the system does")

    var intent = CustomSleepTimerIntent()
    intent.duration = Measurement(value: 15, unit: .minutes)
    _ = try await intent.perform()

    XCTAssertEqual(SleepTimer.shared.state, .countdown(900))
    XCTAssertFalse(eventsOnMain.isEmpty)
    XCTAssertEqual(eventsOnMain.filter { !$0 }.count, 0, "every sleep timer event fires on main")
  }

  func testEndChapterSleepTimerIntentSetsTheTimerOnMain() async throws {
    XCTAssertFalse(isMainThread(), "the test calls perform() off main, as the system does")

    _ = try await EndChapterSleepTimerIntent().perform()

    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter)
    XCTAssertFalse(eventsOnMain.isEmpty)
    XCTAssertEqual(eventsOnMain.filter { !$0 }.count, 0, "every sleep timer event fires on main")
  }

  func testCancelSleepTimerIntentTurnsTheTimerOffOnMain() async throws {
    XCTAssertFalse(isMainThread(), "the test calls perform() off main, as the system does")

    _ = try await CancelSleepTimerIntent().perform()

    XCTAssertEqual(SleepTimer.shared.state, .off)
    XCTAssertFalse(eventsOnMain.isEmpty)
    XCTAssertEqual(eventsOnMain.filter { !$0 }.count, 0, "every sleep timer event fires on main")
  }

  private func isMainThread() -> Bool {
    Thread.isMainThread
  }
}
