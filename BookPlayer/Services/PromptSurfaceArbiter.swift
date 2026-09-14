//
//  PromptSurfaceArbiter.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import UIKit

/// A surface that can ask the user whether to jump to a position another device reached.
///
/// Returns whether it actually presented: a registered CarPlay manager that cannot put a
/// template on screen has to say so, or the prompt disappears instead of falling back to the
/// phone. Deliberately NOT `@discardableResult` — discarding the answer is the bug.
@MainActor
protocol ResumeOfferPresenting: AnyObject {
  func presentResumeOffer(at remoteTime: TimeInterval) -> Bool
}

/// A surface that can tell the user playback failed.
///
/// Takes the failure rather than a rendered alert, because the two surfaces answer it
/// differently: the phone offers the Media Servers shortcut and prints the underlying error,
/// the car shows one line and an OK, since neither configuring a server nor reading an
/// `NSError` dump is something to do while driving.
@MainActor
protocol PlaybackFailurePresenting: AnyObject {
  func presentPlaybackFailure(_ failure: PlaybackFailure) -> Bool
}

/// Decides WHICH surface talks to the user — and only one ever does.
///
/// `ExternalProgressService` publishes remote positions; this is the single subscriber. Two
/// subscribers each applying half a rule left a gap: the car presented when the app was
/// inactive, but the coordinator had already raised the phone's flag, so a driver who ignored
/// the car alert got asked again on unlocking the phone. A prompt now belongs to whichever
/// surface received it, and the other never sees it.
///
/// Playback failures follow the SAME rule rather than getting their own arbiter, because a
/// second object holding a second copy of "which surface may speak" is exactly the drift that
/// bug came from.
///
/// Created eagerly next to `PlayerState`, not with `CoreServices`: CarPlay registers itself
/// here from `connect()`, which on a cold launch into the car can run before the services
/// exist. Registration and subscription are decoupled so that ordering cannot matter — the
/// previous subscription lived on `CarPlayManager.init` and silently never bound on exactly
/// that path.
@MainActor
final class PromptSurfaceArbiter {
  /// Set by CarPlayManager on connect, cleared on disconnect.
  weak var carPlayPresenter: (ResumeOfferPresenting & PlaybackFailurePresenting)?

  private let playerState: PlayerState
  private let isAppActive: () -> Bool
  private var disposeBag = Set<AnyCancellable>()

  init(
    playerState: PlayerState,
    isAppActive: @escaping () -> Bool = { UIApplication.shared.applicationState == .active }
  ) {
    self.playerState = playerState
    self.isAppActive = isAppActive
  }

  func bind(to service: ExternalProgressService) {
    service.promptablePositionPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] position in
        self?.route(position)
      }
      .store(in: &disposeBag)
  }

  /// The car only when the phone can't ask: an active app shows the SwiftUI alert, and asking
  /// twice for one decision is worse than either surface asking once.
  func route(_ position: ExternalPlaybackProgress) {
    if presentOnCarPlay({ $0.presentResumeOffer(at: position.currentTime) }) { return }

    // Don't clobber a prompt the user is already looking at.
    guard !playerState.showResumePopup else { return }

    playerState.remotePlayTime = position.currentTime
    playerState.showResumePopup = true
  }

  /// Same surface rule as the resume offer. The car is deliberately NOT given a copy when the
  /// app is active: `CPAlertTemplate` is modal on the dashboard until someone taps it, so a
  /// failure caused by a passenger tapping around in the app would block the driver's screen.
  /// The cost is that a failure raised from the car while the app happens to be foregrounded
  /// lands on the phone — accepted, rather than putting modal templates in front of a driver.
  func routeFailure(_ failure: PlaybackFailure) {
    if presentOnCarPlay({ $0.presentPlaybackFailure(failure) }) { return }

    playerState.pendingFailure = failure
  }

  /// Whether the car took it. A presenter that is registered but can no longer present (its
  /// interface controller went away between connect and here) reports false, and the caller
  /// falls through to the phone rather than dropping the prompt on the floor.
  private func presentOnCarPlay(
    _ present: (ResumeOfferPresenting & PlaybackFailurePresenting) -> Bool
  ) -> Bool {
    guard let carPlayPresenter, !isAppActive() else { return false }

    return present(carPlayPresenter)
  }
}
