//
//  LastBookStartPlaybackIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/9/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import AppIntents
import BookPlayerKit
import Foundation
#if MAIN_APP
import UIKit
#endif

@available(macOS 14.0, watchOS 10.0, *)
struct LastBookStartPlaybackIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "intent_lastbook_play_title"

  #if !MAIN_APP
  @Dependency
  var playerLoaderService: PlayerLoaderService

  @Dependency
  var libraryService: LibraryService
  #endif

  func perform() async throws -> some IntentResult {
    #if MAIN_APP
    let coreServices = try await AppServices.shared.awaitCoreServices()
    let playerLoaderService = coreServices.playerLoaderService
    let libraryService = coreServices.libraryService
    #endif

    guard let book = libraryService.getLastPlayedItems(limit: 1)?.first else {
      throw "intent_lastbook_empty_error".localized
    }

    #if MAIN_APP
    let bgTaskID = await MainActor.run {
      UIApplication.shared.beginBackgroundTask(withName: "streaming-playback")
    }

    /// Optimistically mark as playing so widgets show the pause icon
    UserDefaults.sharedDefaults.set(
      book.relativePath,
      forKey: Constants.UserDefaults.sharedWidgetNowPlayingPath
    )

    do {
      try await playerLoaderService.loadPlayer(book.relativePath, autoplay: true)
    } catch {
      UserDefaults.sharedDefaults.removeObject(
        forKey: Constants.UserDefaults.sharedWidgetNowPlayingPath
      )
      if bgTaskID != .invalid {
        await MainActor.run {
          UIApplication.shared.endBackgroundTask(bgTaskID)
        }
      }
      throw error
    }

    Task { @MainActor in
      await playerLoaderService.playerManager.awaitCurrentLoad()
      if bgTaskID != .invalid {
        UIApplication.shared.endBackgroundTask(bgTaskID)
      }
    }
    #else
    try await playerLoaderService.loadPlayer(book.relativePath, autoplay: true)
    #endif

    return .result()
  }
}
