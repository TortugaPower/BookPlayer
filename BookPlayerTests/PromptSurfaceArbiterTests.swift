//
//  PromptSurfaceArbiterTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

// MARK: - Resume offer routing

/// One surface asks, never two: the arbiter is the single subscriber to the service.
@MainActor
final class PromptSurfaceArbiterTests: XCTestCase {
  private final class PresenterSpy: ResumeOfferPresenting, PlaybackFailurePresenting {
    var presentedTimes: [TimeInterval] = []
    var presentedFailures: [PlaybackFailure] = []
    /// False stands in for a registered car whose interface controller has gone away.
    var canPresent = true

    func presentResumeOffer(at remoteTime: TimeInterval) -> Bool {
      guard canPresent else { return false }
      presentedTimes.append(remoteTime)
      return true
    }

    func presentPlaybackFailure(_ failure: PlaybackFailure) -> Bool {
      guard canPresent else { return false }
      presentedFailures.append(failure)
      return true
    }
  }

  private let position = ExternalPlaybackProgress(currentTime: 480, lastPlayedDate: Date())

  func testWithoutCarPlayThePhoneGetsTheOffer() {
    let playerState = PlayerState()
    let sut = PromptSurfaceArbiter(playerState: playerState, isAppActive: { false })

    sut.route(position)

    XCTAssertTrue(playerState.showResumePopup)
    XCTAssertEqual(playerState.remotePlayTime, 480)
  }

  /// The driving case: phone in a pocket, car connected. The car asks and the phone's flag is
  /// never raised, so unlocking the phone later cannot ask the same question again.
  func testCarPlayGetsTheOfferWhenTheAppIsInactive() {
    let playerState = PlayerState()
    let car = PresenterSpy()
    let sut = PromptSurfaceArbiter(playerState: playerState, isAppActive: { false })
    sut.carPlayPresenter = car

    sut.route(position)

    XCTAssertEqual(car.presentedTimes, [480])
    XCTAssertFalse(playerState.showResumePopup, "an offer routed to the car leaves no phone flag behind")
    XCTAssertNil(playerState.remotePlayTime)
  }

  /// Phone in hand with the car connected: the SwiftUI alert is the better surface, and the
  /// car must stay quiet rather than ask in parallel.
  func testThePhoneWinsWhenTheAppIsActiveEvenWithCarPlayConnected() {
    let playerState = PlayerState()
    let car = PresenterSpy()
    let sut = PromptSurfaceArbiter(playerState: playerState, isAppActive: { true })
    sut.carPlayPresenter = car

    sut.route(position)

    XCTAssertTrue(car.presentedTimes.isEmpty)
    XCTAssertTrue(playerState.showResumePopup)
  }

  func testAnOfferAlreadyShowingIsNotClobbered() {
    let playerState = PlayerState()
    playerState.showResumePopup = true
    playerState.remotePlayTime = 120
    let sut = PromptSurfaceArbiter(playerState: playerState, isAppActive: { true })

    sut.route(position)

    XCTAssertEqual(playerState.remotePlayTime, 120, "the prompt the user is looking at keeps its position")
  }

  /// Disconnecting the car must hand the next offer back to the phone.
  func testAReleasedPresenterFallsBackToThePhone() {
    let playerState = PlayerState()
    let sut = PromptSurfaceArbiter(playerState: playerState, isAppActive: { false })
    var car: PresenterSpy? = PresenterSpy()
    sut.carPlayPresenter = car
    car = nil

    sut.route(position)

    XCTAssertTrue(playerState.showResumePopup, "a weak presenter that went away is the same as none")
  }
}

// MARK: - Playback failure routing

/// Same surface rule as the resume offer, deliberately: a second copy of "which surface may
/// speak" is the drift the arbiter exists to prevent.
@MainActor
final class PlaybackFailureRoutingTests: XCTestCase {
  private final class PresenterSpy: ResumeOfferPresenting, PlaybackFailurePresenting {
    var presentedFailures: [PlaybackFailure] = []
    var canPresent = true

    func presentResumeOffer(at remoteTime: TimeInterval) -> Bool { canPresent }

    func presentPlaybackFailure(_ failure: PlaybackFailure) -> Bool {
      guard canPresent else { return false }
      presentedFailures.append(failure)
      return true
    }
  }

  private let failure = PlaybackFailure(
    reason: .streamUnavailable,
    phoneTitle: "Error 1234",
    phoneMessage: "the underlying NSError dump",
    canOfferMediaServers: true
  )

  func testWithoutCarPlayTheFailureWaitsOnThePhone() {
    let playerState = PlayerState()
    let sut = PromptSurfaceArbiter(playerState: playerState, isAppActive: { false })

    sut.routeFailure(failure)

    XCTAssertEqual(playerState.pendingFailure, failure)
  }

  /// The case the whole change exists for: streaming fails in the car with the phone locked.
  /// The old code walked to a foregroundActive UIWindowScene, found none, and dropped it.
  func testCarPlayGetsTheFailureWhenTheAppIsInactive() {
    let playerState = PlayerState()
    let car = PresenterSpy()
    let sut = PromptSurfaceArbiter(playerState: playerState, isAppActive: { false })
    sut.carPlayPresenter = car

    sut.routeFailure(failure)

    XCTAssertEqual(car.presentedFailures, [failure])
    XCTAssertNil(playerState.pendingFailure, "a failure routed to the car leaves nothing behind")
  }

  /// Phone in hand with the car connected — a passenger tapping around, or parked. The car
  /// stays quiet on purpose: CPAlertTemplate is modal on the dashboard until someone taps it.
  func testThePhoneWinsWhenTheAppIsActiveEvenWithCarPlayConnected() {
    let playerState = PlayerState()
    let car = PresenterSpy()
    let sut = PromptSurfaceArbiter(playerState: playerState, isAppActive: { true })
    sut.carPlayPresenter = car

    sut.routeFailure(failure)

    XCTAssertTrue(car.presentedFailures.isEmpty)
    XCTAssertEqual(playerState.pendingFailure, failure)
  }

  /// Registered but unable to present: the interface controller went away between connect and
  /// here. An error must fall back to the phone rather than vanish.
  func testACarThatCannotPresentFallsBackToThePhone() {
    let playerState = PlayerState()
    let car = PresenterSpy()
    car.canPresent = false
    let sut = PromptSurfaceArbiter(playerState: playerState, isAppActive: { false })
    sut.carPlayPresenter = car

    sut.routeFailure(failure)

    XCTAssertTrue(car.presentedFailures.isEmpty)
    XCTAssertEqual(playerState.pendingFailure, failure, "a declined presentation is not a delivered one")
  }

  func testAReleasedPresenterFallsBackToThePhone() {
    let playerState = PlayerState()
    let sut = PromptSurfaceArbiter(playerState: playerState, isAppActive: { false })
    var car: PresenterSpy? = PresenterSpy()
    sut.carPlayPresenter = car
    car = nil

    sut.routeFailure(failure)

    XCTAssertEqual(playerState.pendingFailure, failure)
  }

  /// Unlike the resume offer, a newer failure replaces an older one: the second attempt is
  /// what the user just did, so its error is the relevant one.
  func testANewerFailureReplacesThePendingOne() {
    let playerState = PlayerState()
    let sut = PromptSurfaceArbiter(playerState: playerState, isAppActive: { true })
    sut.routeFailure(failure)

    let newer = PlaybackFailure(
      reason: .missingConnection,
      phoneTitle: "Error 5678",
      phoneMessage: nil,
      canOfferMediaServers: false
    )
    sut.routeFailure(newer)

    XCTAssertEqual(playerState.pendingFailure, newer)
  }
}

// MARK: - Surface-specific copy

final class PlaybackFailureCopyTests: XCTestCase {
  private static let phoneTitleSentinel = "Error 1234"
  private static let phoneMessageSentinel = "NSCocoaErrorDomain userInfo={dump}"

  private func failure(_ reason: PlaybackFailure.Reason) -> PlaybackFailure {
    PlaybackFailure(
      reason: reason,
      phoneTitle: Self.phoneTitleSentinel,
      phoneMessage: Self.phoneMessageSentinel,
      canOfferMediaServers: true
    )
  }

  /// The car never shows an error code or an NSError dump, and it points at the one device
  /// where a media server can actually be configured.
  func testTheCarGetsItsOwnLineNotTheTechnicalDetail() {
    for reason in [PlaybackFailure.Reason.missingConnection, .streamUnavailable, .other] {
      let message = failure(reason).carPlayMessage

      XCTAssertFalse(message.isEmpty)
      XCTAssertFalse(
        message.contains(Self.phoneTitleSentinel),
        "an error code has no business on a dashboard"
      )
      XCTAssertFalse(
        message.contains(Self.phoneMessageSentinel),
        "the phone's technical detail must not reach the dashboard"
      )
    }
  }

  /// A host with no saved connection is a different problem from a server that won't answer,
  /// and the car words it differently.
  ///
  /// Asserts the key RESOLVES as well as matching: `.localized` hands back the key itself when
  /// the entry is missing, so comparing two `.localized` calls alone would still pass after
  /// someone deleted the string.
  func testAMissingConnectionGetsItsOwnExplanation() {
    let missing = failure(.missingConnection).carPlayMessage
    let unavailable = failure(.streamUnavailable).carPlayMessage

    XCTAssertEqual(missing, "carplay_missing_connection_message".localized)
    XCTAssertNotEqual(missing, "carplay_missing_connection_message", "the string is missing")

    XCTAssertEqual(unavailable, "carplay_playback_failed_message".localized)
    XCTAssertNotEqual(unavailable, "carplay_playback_failed_message", "the string is missing")

    XCTAssertNotEqual(missing, unavailable, "the two problems read the same to the driver")
  }

  /// The fallback is what `.other` gets — a local file that won't open, no server involved —
  /// and what an unentitled user gets. It must not send either of them to look at a media
  /// server, which is the whole point of gating the other string.
  func testTheFallbackGivesNoMediaServerAdvice() {
    let fallback = failure(.other).carPlayMessage

    XCTAssertFalse(fallback.localizedCaseInsensitiveContains("media server"))
    XCTAssertFalse(fallback.localizedCaseInsensitiveContains("connect"))
  }

  /// The car must not tell a tier that cannot stream to go connect a server — the phone hides
  /// its shortcut for that exact user, and the two surfaces have to agree.
  func testAnUnentitledUserIsNotToldToConnectAServer() {
    let unentitled = PlaybackFailure(
      reason: .missingConnection,
      phoneTitle: Self.phoneTitleSentinel,
      phoneMessage: Self.phoneMessageSentinel,
      canOfferMediaServers: false
    )

    XCTAssertEqual(unentitled.carPlayMessage, "carplay_playback_failed_message".localized)
  }
}

// MARK: - Which alert gets the one slot

/// SwiftUI presents one alert per view, and both prompts hang off the same two attachment
/// points — so the bindings, not luck, have to decide which one appears.
@MainActor
final class PromptBindingPrecedenceTests: XCTestCase {
  func testAPendingFailureSuppressesTheResumeOffer() {
    let playerState = PlayerState()
    playerState.showResumePopup = true
    playerState.pendingFailure = PlaybackFailure(
      reason: .streamUnavailable,
      phoneTitle: "Error 1234",
      phoneMessage: nil,
      canOfferMediaServers: false
    )

    XCTAssertFalse(
      playerState.showResumePopupBinding(whenPlayerVisible: false).wrappedValue,
      "two live bindings would drop one alert with its flag still set"
    )
    XCTAssertTrue(playerState.pendingFailureBinding(whenPlayerVisible: false).wrappedValue)
  }

  /// The offer is deferred, not discarded.
  func testTheResumeOfferReturnsOnceTheFailureIsDismissed() {
    let playerState = PlayerState()
    playerState.showResumePopup = true
    playerState.pendingFailure = PlaybackFailure(
      reason: .other,
      phoneTitle: "t",
      phoneMessage: nil,
      canOfferMediaServers: false
    )

    playerState.pendingFailureBinding(whenPlayerVisible: false).wrappedValue = false

    XCTAssertNil(playerState.pendingFailure)
    XCTAssertTrue(playerState.showResumePopupBinding(whenPlayerVisible: false).wrappedValue)
  }

  /// Only the copy in the live presentation context may present.
  func testOnlyOneContextCopyIsEverEligible() {
    let playerState = PlayerState()
    playerState.pendingFailure = PlaybackFailure(
      reason: .other,
      phoneTitle: "t",
      phoneMessage: nil,
      canOfferMediaServers: false
    )

    playerState.isShowingPlayer = false
    XCTAssertTrue(playerState.pendingFailureBinding(whenPlayerVisible: false).wrappedValue)
    XCTAssertFalse(playerState.pendingFailureBinding(whenPlayerVisible: true).wrappedValue)

    playerState.isShowingPlayer = true
    XCTAssertFalse(playerState.pendingFailureBinding(whenPlayerVisible: false).wrappedValue)
    XCTAssertTrue(playerState.pendingFailureBinding(whenPlayerVisible: true).wrappedValue)
  }

  func testClearPromptsRetiresBoth() {
    let playerState = PlayerState()
    playerState.showResumePopup = true
    playerState.remotePlayTime = 480
    playerState.pendingFailure = PlaybackFailure(
      reason: .other,
      phoneTitle: "t",
      phoneMessage: nil,
      canOfferMediaServers: false
    )

    playerState.clearPrompts()

    XCTAssertFalse(playerState.showResumePopup)
    XCTAssertNil(playerState.remotePlayTime)
    XCTAssertNil(playerState.pendingFailure)
  }
}

