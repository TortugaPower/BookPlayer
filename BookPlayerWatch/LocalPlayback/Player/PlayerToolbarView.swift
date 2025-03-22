//
//  PlayerToolbarView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 25/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct PlayerToolbarView: View {
  /// PlayerManager needs to be an ObservedObject, otherwise the Published property do not reload properly
  @ObservedObject var playerManager: PlayerManager
  @State var isShowingMoreList: Bool = false

  let coreServices: CoreServices

  init(coreServices: CoreServices) {
    self.coreServices = coreServices
    self.playerManager = coreServices.playerManager
  }

  var body: some View {
    HStack {
      Spacer()

      NavigationLink(
        destination: PlaybackFullControlsView(model: .init(playerManager: playerManager))
      ) {
        ResizeableImageView(name: "dial.max")
          .accessibilityLabel("settings_controls_title".localized)
          .padding(11)
      }
      .buttonStyle(PlainButtonStyle())

      Spacer()

      NavigationLink(
        destination: BookmarksView(model: .init(coreServices: coreServices))
      ) {
        ResizeableImageView(name: "bookmark.fill")
          .accessibilityLabel("bookmarks_title".localized)
          .padding(20)
      }
      .buttonStyle(PlainButtonStyle())

      Spacer()

      Button {
        isShowingMoreList = true
      } label: {
        ResizeableImageView(name: "list.bullet")
          .accessibilityLabel("chapters_title".localized)
          .padding(14)
      }
      .buttonStyle(PlainButtonStyle())

      Spacer()
    }
    .background {
      NavigationLink(
        destination: ChapterListView(
          currentItem: $playerManager.currentItem,
          didSelectChapter: { chapter in
            playerManager.jumpToChapter(chapter)
            isShowingMoreList = false
          }
        ),
        isActive: $isShowingMoreList
      ) {
        EmptyView()
      }
      .buttonStyle(PlainButtonStyle())
      .opacity(0)
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}
