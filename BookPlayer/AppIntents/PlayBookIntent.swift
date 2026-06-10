//
//  PlayBookIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/6/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AppIntents
import BookPlayerKit
import Foundation

/// Plays a specific book chosen by the user, selectable in the Shortcuts app
/// and resolvable by Siri (e.g. "Play ⟨book⟩ in BookPlayer").
@available(macOS 14.0, watchOS 10.0, *)
struct PlayBookIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "intent_play_book_title"

  @Parameter(
    title: "book_title",
    requestValueDialog: IntentDialog("intent_play_book_request_title")
  )
  var book: BookEntity

  init() {}

  init(book: BookEntity) {
    self.book = book
  }

  func perform() async throws -> some IntentResult {
    let coreServices = try await AppServices.shared.awaitCoreServices()

    try await AppServices.shared.loadAndKeepAlive(
      relativePath: book.id,
      playerLoaderService: coreServices.playerLoaderService
    )

    return .result()
  }
}
