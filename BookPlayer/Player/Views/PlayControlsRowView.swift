//
//  PlayControlsRow.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct PlayControlsRowView: View {
  @AppStorage(Constants.UserDefaults.rewindInterval) var rewindInterval: TimeInterval = 30
  @AppStorage(Constants.UserDefaults.forwardInterval) var forwardInterval: TimeInterval = 30
  var isPlaying: Bool
  @EnvironmentObject private var theme: ThemeViewModel
  @EnvironmentObject private var playerManager: PlayerManager
  
  private var rewindImage: Image {
    rewindInterval == Constants.SkipInterval.chapterSkipValue
      ? Image(systemName: "backward.end.fill")
      : Image(.playerIconRewind)
  }

  private var rewindLabelText: String {
    rewindInterval == Constants.SkipInterval.chapterSkipValue
      ? ""
      : "-\(String(Int(rewindInterval.rounded())))"
  }

  private var forwardImage: Image {
    forwardInterval == Constants.SkipInterval.chapterSkipValue
      ? Image(systemName: "forward.end.fill")
      : Image(.playerIconForward)
  }

  private var forwardLabelText: String {
    forwardInterval == Constants.SkipInterval.chapterSkipValue
      ? ""
      : "+\(String(Int(forwardInterval.rounded())))"
  }

  var body: some View {
    HStack(spacing: 0) {
      Spacer()
      PlayerJumpView(backgroundImage: rewindImage, text: rewindLabelText, tintColor: Color(theme.linkColor)) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        playerManager.rewind()
      }
        .accessibilityLabel(VoiceOverService.rewindText())
      Spacer()
      Spacer()
      PlayerJumpView(backgroundImage: Image(systemName: isPlaying ? "pause.fill" : "play.fill"), text: "", tintColor: Color(theme.linkColor)) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        playerManager.playPause()
      }
        .accessibilityLabel(isPlaying ? "pause_title".localized : "play_title".localized)
      Spacer()
      Spacer()
      PlayerJumpView(backgroundImage: forwardImage, text: forwardLabelText, tintColor: Color(theme.linkColor)) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        playerManager.forward()
      }
        .accessibilityLabel(VoiceOverService.fastForwardText())
      Spacer()
    }
    .frame(maxWidth: 400)
    .environment(\.layoutDirection, .leftToRight)
  }
}


#Preview {
  PlayControlsRowView(isPlaying: true)
}
