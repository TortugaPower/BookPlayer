//
//  PlayerMoreListView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 28/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

/// To be used later in the player view
struct PlayerMoreListView: View {
  @ObservedObject var playerManager: PlayerManager
  @Binding var isShowingView: Bool

  init(playerManager: PlayerManager, isShowingView: Binding<Bool>) {
    self.playerManager = playerManager
    self._isShowingView = isShowingView
  }

  var body: some View {
    List {
      NavigationLink(
        destination: ChapterListView(
          currentItem: $playerManager.currentItem,
          didSelectChapter: { chapter in
            playerManager.jumpToChapter(chapter)
            isShowingView = false
          }
        )
      ) {
        Text("chapters_title")
      }
    }
    .environment(\.defaultMinListRowHeight, 40)
  }
}
