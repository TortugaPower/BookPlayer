//
//  PlayerControlsView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 25/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct PlayerControlsView: View {
  @ObservedObject var playerManager: PlayerManager
  @AppStorage(Constants.UserDefaults.rewindInterval) var rewindInterval: TimeInterval = 30
  @AppStorage(Constants.UserDefaults.forwardInterval) var forwardInterval: TimeInterval = 30
  /// Follows the player, which also stops on its own: a book ending, headphones disconnecting
  @State private var isPlaying: Bool

  init(playerManager: PlayerManager) {
    self.playerManager = playerManager
    self._isPlaying = .init(initialValue: playerManager.isPlaying)
  }

  var body: some View {
    GeometryReader { geometry in
      HStack {
        Spacer()
        Button {
          playerManager.rewind()
        } label: {
          SkipIntervalView(
            interval: Int(rewindInterval.rounded()),
            skipDirection: .back
          )
          .padding(10)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(VoiceOverService.rewindText())
        .frame(width: geometry.size.width * 0.28)
        Spacer()
        Button {
          playerManager.playPause()
        } label: {
          ResizeableImageView(
            name: isPlaying
              ? "pause.fill"
              : "play.fill"
          )
          .padding(8)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: geometry.size.width * 0.28)
        .applyPrimaryHandGesture()
        Spacer()
        Button {
          playerManager.forward()
        } label: {
          SkipIntervalView(
            interval: Int(forwardInterval.rounded()),
            skipDirection: .forward
          )
          .padding(10)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(VoiceOverService.fastForwardText())
        .frame(width: geometry.size.width * 0.28)
        Spacer()
      }
      .frame(maxHeight: .infinity)
    }
    .onReceive(
      playerManager.isPlayingPublisher()
        .removeDuplicates()
        .receive(on: DispatchQueue.main)
    ) { isPlaying in
      self.isPlaying = isPlaying
    }
  }
}
