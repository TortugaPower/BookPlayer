//
//  NowPlayingPlaybackControlsView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 13/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct NowPlayingPlaybackControlsView: View {
  @EnvironmentObject var contextManager: ContextManager
  @State var isShowingChapterList: Bool = false

  var body: some View {
    HStack {
      Spacer()

      NavigationLink(
        destination: PlaybackControlsView()
          .environmentObject(contextManager)
      ) {
        ResizeableImageView(name: "dial.max")
          .padding(11)
      }
      .buttonStyle(PlainButtonStyle())

      Spacer()

      VolumeView(type: .companion)

      Spacer()

      ZStack {
        NavigationLink(
          destination: ChapterListView(
            currentItem: $contextManager.applicationContext.currentItem
          ) { chapter in
            contextManager.handleChapterSelected(chapter)
            isShowingChapterList = false
          },
          isActive: $isShowingChapterList
        ) {
          EmptyView()
        }
        .buttonStyle(PlainButtonStyle())
        ResizeableImageView(name: "list.bullet")
          .padding(14)
          .onTapGesture {
            isShowingChapterList = true
          }
      }
      Spacer()
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}
