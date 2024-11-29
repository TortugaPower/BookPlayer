//
//  PlayerMoreListView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 28/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct PlayerMoreListView: View {
  @ObservedObject var playerManager: PlayerManager
  @Binding var isShowingView: Bool

  var body: some View {
    List {
      Button {
        print("Downloading Book")
      } label: {
        Text("Download Book")
      }

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
