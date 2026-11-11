//
//  PlaybackErrorPresenter.swift
//  BookPlayerWatch
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import Foundation

/// The error the player screen's alert shows: a playback failure, or the audio session failing to start.
/// Both arrive after the tap that started playback, from `PlayerManager` and the watch's `PlayerPlatform`
@MainActor
final class PlaybackErrorPresenter: ObservableObject {
  @Published var error: Error?

  func present(_ failure: PlaybackFailure) {
    error = PlaybackFailureAlert(failure: failure)
  }
}

/// A playback failure worded as the phone words it
private struct PlaybackFailureAlert: LocalizedError {
  let failure: PlaybackFailure

  var errorDescription: String? { failure.phoneTitle }
  var recoverySuggestion: String? { failure.phoneMessage }
}
