//
//  MiniPlayerAccessoryView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/9/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct MiniPlayerAccessoryView: View {
  let relativePath: String
  let showPlayer: () -> Void

  @State private var isPlaying: Bool = false
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @EnvironmentObject private var theme: ThemeViewModel
  @EnvironmentObject private var playerManager: PlayerManager

  var voiceOverLabel: String {
    let voiceOverTitle = playerManager.currentItem?.title ?? "voiceover_no_title".localized
    let voiceOverSubtitle = playerManager.currentItem?.author ?? "voiceover_no_author".localized

    return "voiceover_miniplayer_hint".localized
      + ", "
      + String(
        describing: String.localizedStringWithFormat(
          "voiceover_currently_playing_title".localized,
          voiceOverTitle,
          voiceOverSubtitle
        )
      )
  }

  var body: some View {
    Group {
      HStack(spacing: 12) {
        MiniPlayerArtworkView(
          relativePath: relativePath,
          artworkLength: 34
        )
        .accessibilityHidden(true)
        .padding(.leading, 8)

        VStack(alignment: .leading) {
          Text(verbatim: playerManager.currentItem?.title ?? "")
            .foregroundStyle(
              reduceTransparency ? Color.primary : theme.primaryColor
            )
            .bpFont(.miniPlayerTitle)
            .lineLimit(1)

          Text(verbatim: playerManager.currentItem?.author ?? "")
            .foregroundStyle(
              reduceTransparency ? Color.secondary : theme.secondaryColor
            )
            .bpFont(.miniPlayerAuthor)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(voiceOverLabel)
        Button {
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          playerManager.rewind()
        } label: {
          Image(
            systemName: "arrow.counterclockwise"
          )
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 24, height: 20)
          .foregroundStyle(theme.linkColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(VoiceOverService.rewindText())
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
          .frame(width: 24, height: 20)
          .foregroundStyle(theme.linkColor)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, Spacing.S1)
      .padding(.trailing, Spacing.S2)
      .contentShape(Rectangle())
      .onTapGesture {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showPlayer()
      }
    }
    .onReceive(
      playerManager.isPlayingPublisher()
        .receive(on: DispatchQueue.main)
    ) { isPlaying in
      self.isPlaying = isPlaying
    }
  }
}

#Preview {
  MiniPlayerAccessoryView(relativePath: "path/to/file.mp3") {}
}
