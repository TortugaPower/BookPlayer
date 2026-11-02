//
//  SleepTimerOptionTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

/// `SleepTimerOption` is compiled into this target from the widget extension
final class SleepTimerOptionTests: XCTestCase {
  /// Time Listened widgets set up with SiriKit migrate by the `TimerOption` value names: renaming a
  /// case loses the timer people chose
  func testOptionsKeepTheSiriKitValueNames() {
    XCTAssertEqual(
      SleepTimerOption.allCases.map(\.rawValue),
      [
        "cancel", "fiveMinutes", "tenMinutes", "fifteenMinutes", "thirtyMinutes", "fortyFiveMinutes", "oneHour",
        "endChapter",
      ]
    )
  }

  /// The widget link's `seconds`: -1 turns the timer off, -2 waits for the end of the chapter
  func testOptionSeconds() {
    XCTAssertEqual(SleepTimerOption.cancel.seconds, -1)
    XCTAssertEqual(SleepTimerOption.fiveMinutes.seconds, 300)
    XCTAssertEqual(SleepTimerOption.tenMinutes.seconds, 600)
    XCTAssertEqual(SleepTimerOption.fifteenMinutes.seconds, 900)
    XCTAssertEqual(SleepTimerOption.thirtyMinutes.seconds, 1800)
    XCTAssertEqual(SleepTimerOption.fortyFiveMinutes.seconds, 2700)
    XCTAssertEqual(SleepTimerOption.oneHour.seconds, 3600)
    XCTAssertEqual(SleepTimerOption.endChapter.seconds, -2)
  }
}
