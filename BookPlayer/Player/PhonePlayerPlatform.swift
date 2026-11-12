//
//  PhonePlayerPlatform.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import Foundation
import Sentry
import UIKit

/// The iPhone's `PlayerPlatform`
@MainActor
final class PhonePlayerPlatform: PlayerPlatform {
  private let shakeMotionService: ShakeMotionServiceProtocol
  /// Set when audio-session activation fails in the current process, so a later
  /// successful activation can tell whether recovery required an app relaunch.
  private var audioSessionFailedThisSession = false

  init(shakeMotionService: ShakeMotionServiceProtocol) {
    self.shakeMotionService = shakeMotionService
  }

  func activateAudioSession(for item: PlayableItem, origin: PlayOrigin) async -> Bool {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(
        AVAudioSession.Category.playback,
        mode: .spokenAudio,
        options: []
      )
      try audioSession.setActive(true)
      reportAudioSessionRecoveryIfNeeded()
      return true
    } catch {
      guard AppEnvironment.isTestFlight else {
        fatalError("Failed to activate the audio session, \(error), description: \(error.localizedDescription)")
      }
      /// Beta-only: don't hard-crash when the audio session can't be activated.
      /// This happens when another process holds the session in a stuck state
      /// that (so far) only a force-quit clears. Report it to Sentry so we can
      /// confirm whether the stuck state still occurs, and leave the play button
      /// inert — a missed auto-play is strictly better than the app dying in the
      /// background.
      let nsError = error as NSError
      SentrySDK.capture(error: error) { scope in
        scope.setLevel(.error)
        scope.setFingerprint(["audio-session-activation-failure"])
        scope.setTag(value: "audio_session_activation", key: "playback_failure")
        scope.setContext(value: [
          "errorCode": nsError.code,
          "errorDomain": nsError.domain,
          "isOtherAudioPlaying": AVAudioSession.sharedInstance().isOtherAudioPlaying,
          "applicationState": UIApplication.shared.applicationState == .active ? "active" : "background",
          "autoPlayed": origin == .system,
          "relativePath": item.relativePath,
        ], key: "audio_session")
      }
      markAudioSessionFailure(nsError)
      NSLog("[PlayerManager] Audio session activation failed: %@", error.localizedDescription)
      return false
    }
  }

  func deactivateAudioSession() {
    try? AVAudioSession.sharedInstance().setActive(false)
  }

  var defersFolderProgress: Bool {
    UIApplication.shared.applicationState != .active
  }

  func fallbackArtwork() -> UIImage? {
    ArtworkService.generateDefaultArtwork(from: ThemeManager.shared.currentTheme.linkColor)
  }

  func stopShakeDetection() {
    shakeMotionService.stopMotionUpdates()
  }

  func observeFirstShake(_ handler: @escaping () -> Void) {
    shakeMotionService.observeFirstShake(completion: handler)
  }

  /// Settings › Autoplay: off until it's turned on
  var autoplaysNextBook: Bool {
    UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled)
  }

  var restartsFinishedBooks: Bool {
    UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayRestartEnabled)
  }

  /// Persist a marker so the next successful activation can report whether — and how —
  /// the audio session recovered. Beta builds only.
  private func markAudioSessionFailure(_ error: NSError) {
    let defaults = UserDefaults.standard
    defaults.set(Date().timeIntervalSince1970, forKey: Constants.UserDefaults.audioSessionFailureTimestamp)
    defaults.set(error.code, forKey: Constants.UserDefaults.audioSessionFailureCode)
    audioSessionFailedThisSession = true
  }

  /// If a prior activation failure was recorded, report to Sentry that the session
  /// recovered — including whether it took an app relaunch (force-quit / OS kill) to
  /// get audio back. Beta builds only.
  private func reportAudioSessionRecoveryIfNeeded() {
    guard AppEnvironment.isTestFlight else { return }
    let defaults = UserDefaults.standard
    guard
      let failedAt = defaults.object(forKey: Constants.UserDefaults.audioSessionFailureTimestamp) as? Double
    else { return }

    // A marker written in this same process means the session self-healed; a marker
    // from a previous launch means audio only returned after the process restarted.
    let requiredRelaunch = !audioSessionFailedThisSession

    SentrySDK.capture(message: "Audio session recovered after activation failure") { scope in
      scope.setLevel(.info)
      scope.setFingerprint(["audio-session-recovery"])
      scope.setTag(value: "audio_session_recovery", key: "playback_failure")
      scope.setContext(value: [
        "secondsSinceFailure": Int(Date().timeIntervalSince1970 - failedAt),
        "requiredAppRelaunch": requiredRelaunch,
        "previousErrorCode": defaults.integer(forKey: Constants.UserDefaults.audioSessionFailureCode),
      ], key: "audio_session")
    }

    defaults.removeObject(forKey: Constants.UserDefaults.audioSessionFailureTimestamp)
    defaults.removeObject(forKey: Constants.UserDefaults.audioSessionFailureCode)
    audioSessionFailedThisSession = false
  }
}
