//
//  ChapterListView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 20/2/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct ChapterListView: View {
  @Binding var currentItem: PlayableItem?
  var didSelectChapter: (PlayableChapter) -> Void

  var body: some View {
    ScrollViewReader { proxy in
      List {
        if let currentItem {
          ForEach(currentItem.chapters) { chapter in
            Button {
              didSelectChapter(chapter)
            } label: {
              HStack {
                Text(chapter.title)
                if currentItem.currentChapter.index == chapter.index {
                  Spacer()
                  Image(systemName: "checkmark.circle.fill")
                }
              }
            }
            .id(chapter.index)
          }
        }
      }
      .environment(\.defaultMinListRowHeight, 40)
      .onAppear {
        if let currentChapter = currentItem?.currentChapter {
          proxy.scrollTo(currentChapter.index, anchor: .center)
        }
      }
    }
    .navigationTitle("chapters_title")
  }
}
