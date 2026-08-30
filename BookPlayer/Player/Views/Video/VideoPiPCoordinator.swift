//
//  VideoPiPCoordinator.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 15/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import AVKit
import BookPlayerKit

/// Coordinates system Picture in Picture for the player screen's video surface.
///
/// PiP auto-starts only when the hosting layer is visible and playing at the moment
/// the app is backgrounded (`canStartPictureInPictureAutomaticallyFromInline`), which
/// gives the intended behavior for free: leaving the app from the player screen with
/// a playing video starts PiP; anywhere else in the app (or with the player dismissed,
/// which detaches the surface) it doesn't.
@MainActor
final class VideoPiPCoordinator: NSObject, AVPictureInPictureControllerDelegate, BPLogger {
  static let shared = VideoPiPCoordinator()

  private var pipController: AVPictureInPictureController?
  private var bookEndObserver: NSObjectProtocol?

  var isActive: Bool {
    pipController?.isPictureInPictureActive ?? false
  }

  /// Gated on device support and the Picture in Picture setting
  var isEnabled: Bool {
    AVPictureInPictureController.isPictureInPictureSupported()
      && UserDefaults.standard.bool(forKey: Constants.UserDefaults.videoPictureInPictureEnabled)
  }

  override private init() {
    super.init()

    /// The end of the book/video dismisses the PiP window
    bookEndObserver = NotificationCenter.default.addObserver(
      forName: .bookEnd,
      object: nil,
      queue: .main
    ) { _ in
      Task { @MainActor in
        Self.shared.stop()
      }
    }
  }

  func host(playerLayer: AVPlayerLayer) {
    guard isEnabled else {
      release(playerLayer: playerLayer)
      return
    }

    guard pipController?.playerLayer !== playerLayer else { return }

    guard let controller = AVPictureInPictureController(playerLayer: playerLayer) else {
      Self.logger.error("PiP: failed to create controller (unsupported device?)")
      return
    }

    controller.canStartPictureInPictureAutomaticallyFromInline = true
    controller.delegate = self
    pipController = controller
  }

  func release(playerLayer: AVPlayerLayer) {
    guard pipController?.playerLayer === playerLayer else { return }

    pipController?.delegate = nil
    pipController = nil
  }

  func stop() {
    guard isActive else { return }

    pipController?.stopPictureInPicture()
  }

  // MARK: AVPictureInPictureControllerDelegate

  nonisolated func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    Self.logger.error("PiP: failed to start: \(error.localizedDescription)")
  }

  /// The user tapped "return to app" on the PiP window. The player screen is still
  /// presented (PiP can only have started from it), so there's nothing to restore —
  /// just report completion so the system finishes stopping PiP. Playback continues.
  /// Closing the window instead (✕) stops PiP with no restore, and the system pauses
  /// playback — the intended behavior: closing the video means "stop", not "keep listening".
  nonisolated func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    completionHandler(true)
  }
}
