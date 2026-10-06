//
//  PromptSurfaceArbiter.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import UIKit

/// A surface that can tell the user playback failed.
///
/// Returns whether it actually presented: a registered CarPlay manager that cannot put a
/// template on screen (its interface controller went away between connect and here) has to say
/// so, or the failure disappears instead of falling back to the phone. Deliberately NOT
/// `@discardableResult` — discarding the answer is the bug.
///
/// Takes the failure rather than a rendered alert, because the two surfaces answer it
/// differently: the phone offers the Media Servers shortcut and prints the underlying error,
/// the car shows one line and an OK, since neither configuring a server nor reading an
/// `NSError` dump is something to do while driving.
@MainActor
protocol PlaybackFailurePresenting: AnyObject {
  func presentPlaybackFailure(_ failure: PlaybackFailure) -> Bool
}

/// Decides WHICH surface tells the user playback failed — and only one ever does.
///
/// A failure belongs to whichever surface received it, and the other never sees it. Two
/// surfaces each applying half a rule left a gap: the car presented when the app was inactive,
/// while the phone had already raised its own flag, so a driver who dismissed the car alert got
/// told again on unlocking the phone.
///
/// Created eagerly next to `PlayerState`, not with `CoreServices`: CarPlay registers itself
/// here from `connect()`, which on a cold launch into the car can run before the services
/// exist, so the ordering can't matter.
@MainActor
final class PromptSurfaceArbiter {
  /// Set by CarPlayManager on connect, cleared on disconnect.
  weak var carPlayPresenter: PlaybackFailurePresenting?

  private let playerState: PlayerState
  private let isAppActive: () -> Bool

  init(
    playerState: PlayerState,
    isAppActive: @escaping () -> Bool = { UIApplication.shared.applicationState == .active }
  ) {
    self.playerState = playerState
    self.isAppActive = isAppActive
  }

  /// The car only when the phone can't show it. The car is deliberately NOT given a copy when
  /// the app is active: `CPAlertTemplate` is modal on the dashboard until someone taps it, so a
  /// failure caused by a passenger tapping around in the app would block the driver's screen.
  /// The cost is that a failure raised from the car while the app happens to be foregrounded
  /// lands on the phone — accepted, rather than putting modal templates in front of a driver.
  func routeFailure(_ failure: PlaybackFailure) {
    if let carPlayPresenter, !isAppActive(), carPlayPresenter.presentPlaybackFailure(failure) {
      return
    }

    playerState.pendingFailure = failure
  }
}
