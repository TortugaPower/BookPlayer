//
//  NowPlayingPlaybackControlsView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 13/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct NowPlayingPlaybackControlsView: View {
  @EnvironmentObject var contextManager: ContextManager

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

      NavigationLink(
        destination: ChapterListView()
          .environmentObject(contextManager)
      ) {
        ResizeableImageView(name: "list.bullet")
          .padding(14)
      }
      .buttonStyle(PlainButtonStyle())

      Spacer()
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}
