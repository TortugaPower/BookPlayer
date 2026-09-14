//
//  PlaybackAlerts.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// Every alert the player raises, declared once and attached twice.
///
/// A `fullScreenCover` is its own presentation context: an alert attached beneath it cannot
/// present over it, and one attached inside it does not exist while the player is closed —
/// and playback starts (and fails) from the mini-player, CarPlay, remote commands and
/// last-book restore, not just from the open player. So both copies have to exist, and
/// `whenPlayerVisible` is what guarantees exactly one of them is ever eligible.
///
/// Bundling them keeps the number of attachment points at two no matter how many alerts the
/// player grows.
struct PlaybackAlerts: ViewModifier {
  let playerState: PlayerState
  let playerManager: PlayerManager
  /// Which of the two presentation contexts this copy lives in.
  let whenPlayerVisible: Bool

  func body(content: Content) -> some View {
    /// Read both flags in `body`, not only inside the Binding getters: with `@Observable`, the
    /// thing that registers this modifier as a dependency is a read during body evaluation,
    /// and these two are the only state that makes it present at all.
    _ = playerState.showResumePopup
    _ = playerState.pendingFailure

    return content
      .alert(
        "resume_playback_alert_title".localized,
        isPresented: playerState.showResumePopupBinding(whenPlayerVisible: whenPlayerVisible)
      ) {
        Button("yes_button".localized) { playerManager.jumpTo(playerState.remotePlayTime ?? 0) }
        Button("ignore_button".localized, role: .cancel) {}
      } message: {
        Text(
          String(
            format: "resume_playback_alert_message".localized,
            TimeParser.formatTime(playerState.remotePlayTime ?? 0)
          )
        )
      }
      .alert(
        playerState.pendingFailure?.phoneTitle ?? "",
        isPresented: playerState.pendingFailureBinding(whenPlayerVisible: whenPlayerVisible),
        presenting: playerState.pendingFailure
      ) { failure in
        /// No `.cancel` role, matching `BPActionItem.okAction` and the CarPlay copy: the role
        /// would emphasize Media Servers over OK and add outside-tap dismissal, neither of
        /// which the UIKit alert this replaced did.
        Button("ok_button".localized) {}
        if failure.canOfferMediaServers {
          Button("media_servers_title".localized) {
            NotificationCenter.default.post(name: .showMediaServers, object: nil)
          }
        }
      } message: { failure in
        if let message = failure.phoneMessage {
          Text(message)
        }
      }
  }
}

extension View {
  func playbackAlerts(
    playerState: PlayerState,
    playerManager: PlayerManager,
    whenPlayerVisible: Bool
  ) -> some View {
    modifier(
      PlaybackAlerts(
        playerState: playerState,
        playerManager: playerManager,
        whenPlayerVisible: whenPlayerVisible
      )
    )
  }
}
