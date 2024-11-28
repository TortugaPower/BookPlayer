//
//  RemotePlayerView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 25/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct RemotePlayerView: View {
  @ObservedObject var playerManager: PlayerManager

  var body: some View {
    VStack {
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
  }
}
