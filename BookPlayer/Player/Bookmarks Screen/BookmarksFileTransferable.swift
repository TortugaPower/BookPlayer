//
//  BookmarksFileTransferable.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct BookmarksFileTransferable: Transferable {
  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .text) { file in
      return file.parseBookmarksData()
    }
    .suggestedFileName { file in
      return "bookmarks_title".localized + " \(file.currentItem.title).txt"
    }
  }

  let currentItem: PlayableItem
  let bookmarks: [SimpleBookmark]

  func parseBookmarksData() -> Data {
    var fileContents = ""

    for bookmark in bookmarks {
      guard let chapter = currentItem.getChapter(at: bookmark.time) else { continue }
      let chapterTime = currentItem.getChapterTime(in: chapter, for: bookmark.time)
      let formattedTime = TimeParser.formatTime(
        chapterTime,
        units: [.hour, .minute, .second]
      )

      var chapterTitle = String.localizedStringWithFormat("chapter_number_title".localized, chapter.index)
      /// Add title if it's different from the numeric title (do not consider volumes as titles would be numeric)
      if !currentItem.isBoundBook,
         chapterTitle.lowercased() != chapter.title.lowercased() {
        chapterTitle += " – \(chapter.title)"
      }

      fileContents += chapterTitle
      + " / \(formattedTime)\n"
      if currentItem.isBoundBook {
        fileContents += "\("title_button".localized): \(chapter.title)\n"
      }
      if let note = bookmark.note {
        fileContents += "\("note_title".localized): \(note)\n"
      }
      fileContents += "----\n"
    }

    return fileContents.data(using: .utf8)!
  }
}
