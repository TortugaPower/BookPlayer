//
//  MiniPlayerView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct MiniPlayerView: View {
  let relativePath: String
  let showPlayer: () -> Void

  @State private var isPlaying: Bool = false

  @EnvironmentObject private var theme: ThemeViewModel
  @EnvironmentObject private var playerManager: PlayerManager

  var voiceOverLabel: String {
    let voiceOverTitle = playerManager.currentItem?.title ?? "voiceover_no_title".localized
    let voiceOverSubtitle = playerManager.currentItem?.author ?? "voiceover_no_author".localized

    return "voiceover_miniplayer_hint".localized
    + ", "
    + String(describing: String.localizedStringWithFormat("voiceover_currently_playing_title".localized, voiceOverTitle, voiceOverSubtitle))
  }

  var body: some View {
    Group {
      HStack(spacing: 9) {
        MiniPlayerArtworkView(relativePath: relativePath)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 8) {
          Text(verbatim: playerManager.currentItem?.title ?? "")
            .foregroundStyle(theme.primaryColor)
            .bpFont(Fonts.miniPlayerTitle)
            .lineLimit(1)
          Text(verbatim: playerManager.currentItem?.author ?? "")
            .foregroundStyle(theme.secondaryColor)
            .bpFont(Fonts.miniPlayerTitle)
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(voiceOverLabel)
        Spacer()
        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          playerManager.playPause()
        } label: {
          Image(
            systemName: isPlaying
            ? "pause.fill"
            : "play.fill"
          )
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 48, height: 28)
          .foregroundStyle(theme.linkColor)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, Spacing.S1)
      .frame(height: 72)
      .background(theme.secondarySystemBackgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 13))
      .contentShape(Rectangle())
      .onTapGesture {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showPlayer()
      }
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 49 + 12)
    .shadow(color: theme.primaryColor.opacity(0.18), radius: 9)
    .onReceive(
      playerManager.isPlayingPublisher()
        .receive(on: DispatchQueue.main)
    ) { isPlaying in
      self.isPlaying = isPlaying
    }
  }
}

#Preview {
  MiniPlayerView(relativePath: "path/to/file.mp3") {}
}
