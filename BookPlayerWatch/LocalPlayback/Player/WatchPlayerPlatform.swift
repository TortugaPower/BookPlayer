//
//  WatchPlayerPlatform.swift
//  BookPlayerWatch
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import BookPlayerWatchKit
import Foundation
import UIKit

/// The watch's `PlayerPlatform`
@MainActor
final class WatchPlayerPlatform: PlayerPlatform {
  private let playbackErrors: PlaybackErrorPresenter

  init(playbackErrors: PlaybackErrorPresenter) {
    self.playbackErrors = playbackErrors
  }

  /// Long-form audio, so activating waits on the route picker until Bluetooth headphones are chosen.
  /// A failure is shown and the play goes on
  func activateAudioSession(for item: PlayableItem, origin: PlayOrigin) async -> Bool {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(
        AVAudioSession.Category.playback,
        mode: .spokenAudio,
        policy: .longFormAudio,
        options: []
      )
      try await audioSession.activate()
    } catch {
      playbackErrors.error = error
    }
    return true
  }

  func deactivateAudioSession() {
    try? AVAudioSession.sharedInstance().setActive(false)
  }

  /// The watch marks a book's folders stale instead of recalculating their progress while it plays
  let defersFolderProgress = true

  func fallbackArtwork() -> UIImage? {
    nil
  }

  func stopShakeDetection() {}

  func observeFirstShake(_ handler: @escaping () -> Void) {}

  /// The player's Autoplay toggle, on until it's turned off
  var autoplaysNextBook: Bool {
    UserDefaults.standard.object(forKey: Constants.UserDefaults.autoplayEnabled) as? Bool ?? true
  }

  let restartsFinishedBooks = true
}
