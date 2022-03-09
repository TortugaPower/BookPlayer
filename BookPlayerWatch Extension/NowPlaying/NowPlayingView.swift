//
//  NowPlayingView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 19/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct NowPlayingView: View {
  let item: PlayableItem

  var body: some View {
    VStack {
      NowPlayingTitleView(author: item.author, title: item.title)
      Spacer()
      HStack {
        Button {
          print("rewind tapped")
        } label: {
          ZStack {
            Text("**300**")
              .minimumScaleFactor(0.1)
              .lineLimit(1)
              .padding(5)
              .offset(y: 1)
            ResizeableImageView(name: "gobackward")
          }
          .padding(14)

//          ResizeableImageView(name: "gobackward")
//            .padding(12)
        }
        .buttonStyle(PlainButtonStyle())

        Button {
          print("play tapped")
        } label: {
          ResizeableImageView(name: "play.fill")
            .padding(8)
        }
        .buttonStyle(PlainButtonStyle())

        Button {
          print("forward tapped")
        } label: {
          ResizeableImageView(name: "goforward")
            .padding(12)
        }
        .buttonStyle(PlainButtonStyle())
      }

      Spacer()
      HStack {
        NavigationLink(destination: PlaybackControlsView()) {
          ResizeableImageView(name: "dial.max")
            .padding(11)
        }
        .buttonStyle(PlainButtonStyle())

        VolumeView()

        NavigationLink(destination: ChapterListView(currentChapter: item.currentChapter, chapters: item.chapters)) {
          ResizeableImageView(name: "list.bullet")
            .padding(14)
        }
        .buttonStyle(PlainButtonStyle())
      }
    }
    .ignoresSafeArea(edges: .bottom)
  }
}

struct NowPlayingView_Previews: PreviewProvider {
  static var previews: some View {
    NowPlayingView(item: PlayableItem(
      title: "book 1 book 1 book 1 book 1 book 1",
      author: "author 1",
      chapters: [],
      currentTime: 0,
      duration: 0,
      relativePath: "book 1",
      percentCompleted: 0,
      isFinished: false,
      useChapterTimeContext: false
    ))
  }
}
