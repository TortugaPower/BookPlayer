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
      try await AppServices.shared.loadAndKeepAlive(
        relativePath: relativePath,
        playerLoaderService: playerLoaderService
      )
      #else
      try await playerLoaderService.loadPlayer(relativePath, autoplay: true)
      #endif
    }

    return .result()
  }
}
