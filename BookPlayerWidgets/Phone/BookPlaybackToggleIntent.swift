//
//  BookPlaybackToggleIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/11/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
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

  @Dependency
  var playerLoaderService: PlayerLoaderService

  init() {
    self.relativePath = ""
  }

  init(relativePath: String) {
    self.relativePath = relativePath
  }

  func perform() async throws -> some IntentResult {
    if playerLoaderService.playerManager.currentItem?.relativePath == relativePath {
      playerLoaderService.playerManager.playPause()
    } else {
      try await playerLoaderService.loadPlayer(relativePath, autoplay: true)
    }

    return .result()
  }
}
