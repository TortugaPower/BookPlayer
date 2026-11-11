//
//  RemotePlayerView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 25/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct RemotePlayerView: View {
  @ObservedObject var playerManager: PlayerManager
  @ObservedObject var playbackErrors: PlaybackErrorPresenter
  let coreServices: CoreServices
  /// Where playback is in the book, 0 to 1. Refreshing it each second also redraws the remaining time
  @State private var progress: Double

  init(coreServices: CoreServices) {
    self.coreServices = coreServices
    self.playerManager = coreServices.playerManager
    self.playbackErrors = coreServices.playbackErrors
    self._progress = .init(initialValue: coreServices.playerManager.currentItem?.progressPercentage ?? 0)
  }

  var body: some View {
    VStack {
      
      if playerManager.currentItem != nil {
        LinearProgressView(
          value: progress,
          fillColor: .accentColor
        )
        .accessibilityHidden(true)
        .frame(maxHeight: 3)
      }

      NowPlayingTitleView(
        item: $playerManager.currentItem
      )

      Spacer()

      PlayerControlsView(playerManager: playerManager)

      Spacer()

      PlayerToolbarView(coreServices: coreServices)
    }
    .background {
      VolumeView(type: .local)
        .accessibilityHidden(true)
        .opacity(0)
    }
    .fixedSize(horizontal: false, vertical: false)
    .ignoresSafeArea(edges: .bottom)
    .navigationTitle(
      TimeParser.formatTotalDuration(playerManager.currentItem?.maxTimeInContext(prefersChapterContext: false, prefersRemainingTime: true, at: playerManager.currentSpeed) ?? 0)
    )
    /// The player posts it every second while playing and after each seek, paused too
    .onReceive(NotificationCenter.default.publisher(for: .bookPlaying)) { _ in
      progress = playerManager.currentItem?.progressPercentage ?? 0
    }
    /// Another book, which can load without playing (the next one, with the end-of-chapter timer on)
    .onReceive(playerManager.$currentItem) { item in
      progress = item?.progressPercentage ?? 0
    }
    .errorAlert(error: $playbackErrors.error)
  }
}
