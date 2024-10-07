//
//  LastBookStartPlaybackIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/9/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import AppIntents
import BookPlayerKit
import Foundation

@available(iOS 16.0, macOS 14.0, watchOS 10.0, *)
struct LastBookStartPlaybackIntent: AudioStartingIntent {
  static var title: LocalizedStringResource = "intent_lastbook_play_title"

  @Dependency
  var playerLoaderService: PlayerLoaderService

  @Dependency
  var libraryService: LibraryService

  func perform() async throws -> some IntentResult {
    guard let book = libraryService.getLastPlayedItems(limit: 1)?.first else {
      throw "intent_lastbook_empty_error".localized
    }

    try await playerLoaderService.loadPlayer(book.relativePath, autoplay: true)

    return .result()
  }
}
