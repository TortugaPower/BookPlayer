//
//  PlayerTimeSampleTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 5/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

@testable import BookPlayer
import XCTest

class PlayerTimeSampleTests: XCTestCase {
  func testAcceptsRegularPosition() {
    XCTAssertEqual(PlayerTimeSample(playerTime: 1643.6, expected: 1642.6), .valid(1643.6))
  }

  func testRecoversFromWrappedNegativeClock() {
    // Observed on iOS 27 + CarPlay: the real position minus 2^32 samples at 48 kHz
    let wrapped = 1643.599 - 4_294_967_296 / 48_000
    XCTAssertEqual(PlayerTimeSample(playerTime: wrapped, expected: 1643.599), .recover)
  }

  func testRecoversFromAnyNegativeWellIntoFile() {
    XCTAssertEqual(PlayerTimeSample(playerTime: -0.3, expected: 120), .recover)
  }

  func testIgnoresSmallNegativeAtFileStart() {
    // Output latency right after a bound-book chapter switch (AirPlay)
    XCTAssertEqual(PlayerTimeSample(playerTime: -0.4, expected: 0), .ignore)
    XCTAssertEqual(PlayerTimeSample(playerTime: -0.4, expected: nil), .ignore)
  }

  func testHandlesInvalidTime() {
    XCTAssertEqual(PlayerTimeSample(playerTime: .nan, expected: 500), .recover)
    XCTAssertEqual(PlayerTimeSample(playerTime: .nan, expected: 0), .ignore)
  }

  func testRecoversFromSnapToFileStart() {
    // Observed on iOS 27 + CarPlay: the paused item snapped to exactly 0 while 27 minutes in
    XCTAssertEqual(PlayerTimeSample(playerTime: 0, expected: 1647.2), .recover)
  }

  func testAcceptsFileStartNearTheStart() {
    // A fresh file, or a Picture in Picture skip-back close to the start
    XCTAssertEqual(PlayerTimeSample(playerTime: 0.2, expected: 0), .valid(0.2))
    XCTAssertEqual(PlayerTimeSample(playerTime: 0, expected: 12), .valid(0))
  }

  func testAcceptsBackwardJumpAwayFromFileStart() {
    // Only the file-start signature counts as a glitch, so skip-backs the player applies stand
    XCTAssertEqual(PlayerTimeSample(playerTime: 1630, expected: 1645), .valid(1630))
  }
}
