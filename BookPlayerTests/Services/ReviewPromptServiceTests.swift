//
//  ReviewPromptServiceTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

@MainActor
final class ReviewPromptServiceTests: XCTestCase {
  var defaults: UserDefaults!
  var promptCount = 0

  static let cooldown: TimeInterval = 120 * 24 * 60 * 60

  override func setUp() {
    super.setUp()
    defaults = UserDefaults(suiteName: "ReviewPromptServiceTests")!
    defaults.removePersistentDomain(forName: "ReviewPromptServiceTests")
    promptCount = 0
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: "ReviewPromptServiceTests")
    super.tearDown()
  }

  func makeSUT(now: Date, version: String? = "1.0.0") -> ReviewPromptService {
    return ReviewPromptService(
      defaults: defaults,
      dateProvider: { now },
      versionProvider: { version },
      presentPrompt: { self.promptCount += 1 }
    )
  }

  func arm() {
    defaults.set(true, forKey: Constants.UserDefaults.pendingReviewPrompt)
  }

  func testNotArmedDoesNothing() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    makeSUT(now: now).requestReviewIfEligible()

    XCTAssertEqual(promptCount, 0)
    XCTAssertNil(defaults.object(forKey: Constants.UserDefaults.lastReviewRequestDate))
  }

  func testFirstRequestPromptsAndRecords() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    arm()

    makeSUT(now: now, version: "1.2.3").requestReviewIfEligible()

    XCTAssertEqual(promptCount, 1)
    XCTAssertFalse(defaults.bool(forKey: Constants.UserDefaults.pendingReviewPrompt))
    XCTAssertEqual(
      defaults.object(forKey: Constants.UserDefaults.lastReviewRequestDate) as? Date,
      now
    )
    XCTAssertEqual(
      defaults.string(forKey: Constants.UserDefaults.lastReviewRequestVersion),
      "1.2.3"
    )
  }

  func testCooldownBlocksAndConsumesFlag() {
    let lastRequest = Date(timeIntervalSince1970: 1_000_000)
    defaults.set(lastRequest, forKey: Constants.UserDefaults.lastReviewRequestDate)
    defaults.set("1.0.0", forKey: Constants.UserDefaults.lastReviewRequestVersion)
    arm()

    let now = lastRequest.addingTimeInterval(Self.cooldown - 1)
    makeSUT(now: now, version: "2.0.0").requestReviewIfEligible()

    XCTAssertEqual(promptCount, 0)
    /// The flag is consumed on failure, so a stale arm can't fire a prompt much later
    XCTAssertFalse(defaults.bool(forKey: Constants.UserDefaults.pendingReviewPrompt))
    /// The stored request date is not overwritten by a blocked evaluation
    XCTAssertEqual(
      defaults.object(forKey: Constants.UserDefaults.lastReviewRequestDate) as? Date,
      lastRequest
    )
  }

  func testSameVersionBlocksAfterCooldown() {
    let lastRequest = Date(timeIntervalSince1970: 1_000_000)
    defaults.set(lastRequest, forKey: Constants.UserDefaults.lastReviewRequestDate)
    defaults.set("1.0.0", forKey: Constants.UserDefaults.lastReviewRequestVersion)
    arm()

    let now = lastRequest.addingTimeInterval(Self.cooldown + 1)
    makeSUT(now: now, version: "1.0.0").requestReviewIfEligible()

    XCTAssertEqual(promptCount, 0)
    XCTAssertFalse(defaults.bool(forKey: Constants.UserDefaults.pendingReviewPrompt))
  }

  func testCooldownElapsedAndNewVersionPrompts() {
    let lastRequest = Date(timeIntervalSince1970: 1_000_000)
    defaults.set(lastRequest, forKey: Constants.UserDefaults.lastReviewRequestDate)
    defaults.set("1.0.0", forKey: Constants.UserDefaults.lastReviewRequestVersion)
    arm()

    let now = lastRequest.addingTimeInterval(Self.cooldown + 1)
    makeSUT(now: now, version: "1.1.0").requestReviewIfEligible()

    XCTAssertEqual(promptCount, 1)
    XCTAssertEqual(
      defaults.object(forKey: Constants.UserDefaults.lastReviewRequestDate) as? Date,
      now
    )
    XCTAssertEqual(
      defaults.string(forKey: Constants.UserDefaults.lastReviewRequestVersion),
      "1.1.0"
    )
  }

  func testFutureLastRequestDateSelfHeals() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let futureRequest = now.addingTimeInterval(60 * 60)
    defaults.set(futureRequest, forKey: Constants.UserDefaults.lastReviewRequestDate)
    defaults.set("1.0.0", forKey: Constants.UserDefaults.lastReviewRequestVersion)
    arm()

    makeSUT(now: now, version: "2.0.0").requestReviewIfEligible()

    XCTAssertEqual(promptCount, 0)
    XCTAssertFalse(defaults.bool(forKey: Constants.UserDefaults.pendingReviewPrompt))
    /// The stored date is rewritten to `now` so the cooldown can elapse again
    XCTAssertEqual(
      defaults.object(forKey: Constants.UserDefaults.lastReviewRequestDate) as? Date,
      now
    )

    /// A full cooldown after the healed date, the prompt fires again
    arm()
    let later = now.addingTimeInterval(Self.cooldown + 1)
    makeSUT(now: later, version: "2.0.0").requestReviewIfEligible()
    XCTAssertEqual(promptCount, 1)
  }

  func testConsecutiveFinishesOnlyPromptOnce() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let sut = makeSUT(now: now, version: "1.0.0")

    arm()
    sut.requestReviewIfEligible()
    arm()
    sut.requestReviewIfEligible()

    XCTAssertEqual(promptCount, 1)
  }
}
