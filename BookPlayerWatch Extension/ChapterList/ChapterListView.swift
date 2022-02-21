//
//  ChapterListView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 20/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct ChapterListView: View {
  let item: PlayableItem

  var body: some View {
    List {
      ForEach(item.chapters) { chapter in
        Button {
          print("chapter selected")
        } label: {
          HStack {
            Text(chapter.title)
            if item.currentChapter.index == chapter.index {
              Spacer()
              Image(systemName: "checkmark.circle.fill")
            }
          }
        }
      }
    }
    .navigationTitle("chapters_title")
  }
}

struct ChapterListView_Previews: PreviewProvider {
  static var previews: some View {
    ChapterListView(item: PlayableItem(
      title: "book 1",
      author: "author 1",
      chapters: [PlayableChapter(
        title: "Chapter 1",
        author: "Author",
        start: 0,
        duration: 0,
        relativePath: "",
        index: 0
      )],
      currentTime: 0,
      duration: 0,
      relativePath: "book 1",
      percentCompleted: 0,
      isFinished: false,
      useChapterTimeContext: false
    ))
  }
}
