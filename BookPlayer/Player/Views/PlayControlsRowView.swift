//
//  PlayControlsRow.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct PlayControlsRowView: View {
  var isPlaying: Bool
  @EnvironmentObject private var theme: ThemeViewModel
  @EnvironmentObject private var playerManager: PlayerManager
  
  var body: some View {
    HStack(spacing: 0) {
      Spacer()
      PlayerJumpView(backgroundImage: Image(.playerIconRewind), text: "-\(String(Int(PlayerManager.rewindInterval.rounded())))", tintColor: Color(theme.linkColor)) {
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
      PlayerJumpView(backgroundImage: Image(.playerIconForward), text: "+\(String(Int(PlayerManager.forwardInterval.rounded())))", tintColor: Color(theme.linkColor)) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        playerManager.forward()
      }
        .accessibilityLabel(VoiceOverService.fastForwardText())
      Spacer()
    }
    .frame(maxWidth: 400)
  }
}


#Preview {
  PlayControlsRowView(isPlaying: true)
}
