//
//  BookmarksActivityItemProvider.swift
//  BookPlayer
//
//  Created by gianni.carlo on 1/9/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

final class BookmarksActivityItemProvider: UIActivityItemProvider {
  let currentItem: PlayableItem
  let bookmarks: [SimpleBookmark]

  init(currentItem: PlayableItem, bookmarks: [SimpleBookmark]) {
    self.currentItem = currentItem
    self.bookmarks = bookmarks
    super.init(placeholderItem: URL(fileURLWithPath: "placeholder.txt"))
  }

  public override func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    let fileTitle = "bookmarks_title".localized + " \(currentItem.title).txt"
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileTitle)

    do {
      if FileManager.default.fileExists(atPath: fileURL.path) {
        try FileManager.default.removeItem(at: fileURL)
      }

      let contentsData = parseBookmarksData()
      FileManager.default.createFile(atPath: fileURL.path, contents: contentsData)
    } catch {
      return nil
    }

    return fileURL
  }

  func parseBookmarksData() -> Data? {
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

    return fileContents.data(using: .utf8)
  }

  public override func activityViewControllerPlaceholderItem(
    _ activityViewController: UIActivityViewController
  ) -> Any {
    return URL(fileURLWithPath: "placeholder.txt")
  }
}
