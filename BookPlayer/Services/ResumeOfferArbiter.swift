//
//  ResumeOfferArbiter.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import UIKit

/// A surface that can ask the user whether to jump to a position another device reached.
@MainActor
protocol ResumeOfferPresenting: AnyObject {
  func presentResumeOffer(at remoteTime: TimeInterval)
}

/// Decides WHICH surface asks about a farther remote position — and only one ever does.
///
/// `ExternalProgressService` publishes the position; this is the single subscriber. Two
/// subscribers each applying half a rule left a gap: the car presented when the app was
/// inactive, but the coordinator had already raised the phone's flag, so a driver who ignored
/// the car alert got asked again on unlocking the phone. An offer now belongs to whichever
/// surface received it, and the other never sees it.
///
/// Created eagerly next to `PlayerState`, not with `CoreServices`: CarPlay registers itself
/// here from `connect()`, which on a cold launch into the car can run before the services
/// exist. Registration and subscription are decoupled so that ordering cannot matter — the
/// previous subscription lived on `CarPlayManager.init` and silently never bound on exactly
/// that path.
@MainActor
final class ResumeOfferArbiter {
  /// Set by CarPlayManager on connect, cleared on disconnect.
  weak var carPlayPresenter: ResumeOfferPresenting?

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
    if let carPlayPresenter, !isAppActive() {
      carPlayPresenter.presentResumeOffer(at: position.currentTime)
      return
    }

    // Don't clobber a prompt the user is already looking at.
    guard !playerState.showResumePopup else { return }

    playerState.remotePlayTime = position.currentTime
    playerState.showResumePopup = true
  }
}
