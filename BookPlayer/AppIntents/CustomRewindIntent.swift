//
//  CustomRewindIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 31/7/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import AppIntents
import BookPlayerKit
import Foundation

@available(iOS 16.0, macOS 14.0, watchOS 10.0, tvOS 16.0, *)
struct CustomRewindIntent: AudioStartingIntent {
  static var title: LocalizedStringResource = "intent_custom_skiprewind_title"

  @Parameter(
    title: LocalizedStringResource("intent_custom_interval_title"),
    requestValueDialog: IntentDialog(LocalizedStringResource("intent_custom_skip_request_title"))
  )
  var interval: Measurement<UnitDuration>

  static var parameterSummary: some ParameterSummary {
    Summary("Rewind \(\.$interval)")
  }

  @Dependency
  var playerLoaderService: PlayerLoaderService

  @Dependency
  var libraryService: LibraryService

  func perform() async throws -> some IntentResult {
    let seconds = interval.converted(to: .seconds).value

    if !playerLoaderService.playerManager.hasLoadedBook(),
      let book = libraryService.getLastPlayedItems(limit: 1)?.first
    {
      try await playerLoaderService.loadPlayer(book.relativePath, autoplay: false)
    }

    playerLoaderService.playerManager.skip(-seconds)

    return .result()
  }
}
