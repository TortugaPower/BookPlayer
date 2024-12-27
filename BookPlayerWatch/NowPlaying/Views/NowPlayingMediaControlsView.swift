//
//  NowPlayingMediaControlsView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 13/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct NowPlayingMediaControlsView: View {
  @EnvironmentObject var contextManager: ContextManager

  var body: some View {
    GeometryReader { geometry in
      HStack {
        Spacer()
        Button {
          contextManager.handleSkip(.back)
        } label: {
          SkipIntervalView(
            interval: contextManager.applicationContext.rewindInterval,
            skipDirection: .back
          )
          .padding(10)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: geometry.size.width * 0.28)
        Spacer()
        Button {
          contextManager.handlePlayPause()
        } label: {
          ResizeableImageView(
            name: contextManager.isPlaying
            ? "pause.fill"
            : "play.fill"
          )
          .padding(8)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: geometry.size.width * 0.28)
        Spacer()
        Button {
          contextManager.handleSkip(.forward)
        } label: {
          SkipIntervalView(
            interval: contextManager.applicationContext.forwardInterval,
            skipDirection: .forward
          )
          .padding(10)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: geometry.size.width * 0.28)
        Spacer()
      }
      .frame(maxHeight: .infinity)
    }
  }
}
