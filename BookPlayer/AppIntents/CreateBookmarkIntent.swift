//
//  CreateBookmarkIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/4/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AppIntents
import BookPlayerKit
import Foundation

@available(macOS 14.0, watchOS 10.0, tvOS 16.0, *)
struct CreateBookmarkIntent: AppIntent {
  static var title: LocalizedStringResource = "bookmark_create_title"

  @Parameter(
    title: LocalizedStringResource("note_title"),
    requestValueDialog: IntentDialog(LocalizedStringResource("bookmark_note_action_title"))
  )
  var note: String?

  @Dependency
  var playerLoaderService: PlayerLoaderService

  @Dependency
  var libraryService: LibraryService

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let currentItem = playerLoaderService.playerManager.currentItem else {
      return .result(
        value: "",
        dialog: IntentDialog(stringLiteral: "intent_lastbook_empty_error".localized)
      )
    }

    let currentTime = currentItem.currentTime

    if let bookmark = self.libraryService.getBookmark(
      at: currentTime,
      relativePath: currentItem.relativePath,
      type: .user
    ) {
      let formattedTime = TimeParser.formatTime(bookmark.time)
      return .result(
        value: "",
        dialog: IntentDialog(
          stringLiteral: String.localizedStringWithFormat("bookmark_exists_title".localized, formattedTime)
        )
      )
    }

    if let bookmark = libraryService.createBookmark(
      at: floor(currentTime),
      relativePath: currentItem.relativePath,
      type: .user
    ) {

      if note == nil {
        let note = try? await $note.requestValue(IntentDialog(stringLiteral: "bookmark_note_action_title".localized))
        self.note = note
      }

      if let note {
        libraryService.addNote(note, bookmark: bookmark)
      }

      playerLoaderService.syncService.scheduleSetBookmark(
        relativePath: currentItem.relativePath,
        time: floor(currentTime),
        note: note
      )

      let formattedTime = TimeParser.formatTime(bookmark.time)
      return .result(
        value: "",
        dialog: IntentDialog(
          stringLiteral: String.localizedStringWithFormat("bookmark_created_title".localized, formattedTime)
        )
      )
    } else {
      return .result(
        value: "",
        dialog: IntentDialog(stringLiteral: "generic_retry_description".localized)
      )
    }
  }
}
