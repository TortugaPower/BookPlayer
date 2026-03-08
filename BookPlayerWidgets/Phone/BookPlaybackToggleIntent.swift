//
//  BookPlaybackToggleIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/11/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import AppIntents
import BookPlayerKit
import Foundation
#if MAIN_APP
import UIKit
import WidgetKit
#endif

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct BookPlaybackToggleIntent: AudioPlaybackIntent {

  static var title: LocalizedStringResource = .init("Toggle playback of book")

  @Parameter(title: "relativePath")
  var relativePath: String

  init() {
    self.relativePath = ""
  }

  init(relativePath: String) {
    self.relativePath = relativePath
  }

  #if !MAIN_APP
  @Dependency
  var playerLoaderService: PlayerLoaderService
  #endif

  func perform() async throws -> some IntentResult {
    #if MAIN_APP
    let coreServices = try await AppServices.shared.awaitCoreServices()
    let playerLoaderService = coreServices.playerLoaderService
    #endif

    if playerLoaderService.playerManager.currentItem?.relativePath == relativePath {
      await MainActor.run {
        playerLoaderService.playerManager.playPause()
      }
    } else {
      #if MAIN_APP
      try await Self.loadAndKeepAlive(relativePath: relativePath, playerLoaderService: playerLoaderService)
      #else
      try await playerLoaderService.loadPlayer(relativePath, autoplay: true)
      #endif
    }

    return .result()
  }

  #if MAIN_APP
  /// Starts playback and keeps the app alive for streaming setup via a background task.
  /// Returns immediately so the widget UI can update, while a detached task
  /// waits for playback to start before ending the background task.
  @MainActor
  private static func loadAndKeepAlive(
    relativePath: String,
    playerLoaderService: PlayerLoaderService
  ) async throws {
    let bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "streaming-playback")

    /// Optimistically mark as playing so widgets show the pause icon
    UserDefaults.sharedDefaults.set(
      relativePath,
      forKey: Constants.UserDefaults.sharedWidgetNowPlayingPath
    )

    try await playerLoaderService.loadPlayer(relativePath, autoplay: true)

    Task { @MainActor in
      await playerLoaderService.playerManager.awaitCurrentLoad()
      if bgTaskID != .invalid {
        UIApplication.shared.endBackgroundTask(bgTaskID)
      }
    }
  }
  #endif
}
