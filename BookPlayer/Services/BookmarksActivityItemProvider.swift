//
//  BookmarksActivityItemProvider.swift
//  BookPlayer
//
//  Created by gianni.carlo on 1/9/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

final class BookmarksActivityItemProvider: UIActivityItemProvider {
  let currentItem: PlayableItem
  let bookmarks: [Bookmark]

  init(currentItem: PlayableItem, bookmarks: [Bookmark]) {
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
      let chapterTime = currentItem.getChapterTime(from: bookmark.time)
      let formattedTime = TimeParser.formatTime(chapterTime)

      fileContents += String.localizedStringWithFormat("chapter_number_title".localized, chapter.index)
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
