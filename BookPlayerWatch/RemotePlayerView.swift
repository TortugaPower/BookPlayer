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

  var body: some View {
    VStack {
      
      if let currentItem = playerManager.currentItem {
        LinearProgressView(
          value: currentItem.currentTime / currentItem.duration,
          fillColor: .accentColor
        )
        .frame(maxHeight: 3)
      }

      NowPlayingTitleView(
        item: $playerManager.currentItem
      )

      Spacer()

      PlayerControlsView(playerManager: playerManager)

      Spacer()

      PlayerToolbarView(playerManager: playerManager)
    }
    .fixedSize(horizontal: false, vertical: false)
    .ignoresSafeArea(edges: .bottom)
    .navigationTitle(TimeParser.formatTotalDuration(playerManager.currentItem?.maxTimeInContext(prefersChapterContext: false, prefersRemainingTime: true, at: 1.0) ?? 0))
    .errorAlert(error: $playerManager.error)
  }
}
