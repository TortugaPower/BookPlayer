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
  let currentChapter: PlayableChapter
  let chapters: [PlayableChapter]

  var body: some View {
    List {
      ForEach(chapters) { chapter in
        Button {
          print("chapter selected")
        } label: {
          HStack {
            Text(chapter.title)
            if currentChapter.index == chapter.index {
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
    ChapterListView(
      currentChapter: PlayableChapter(
        title: "Chapter 1",
        author: "Author",
        start: 0,
        duration: 0,
        relativePath: "",
        index: 0
      ),
      chapters: [
        PlayableChapter(
          title: "Chapter 1",
          author: "Author",
          start: 0,
          duration: 0,
          relativePath: "",
          index: 0
        ),
      ]
    )
  }
}
