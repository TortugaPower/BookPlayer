//
//  PausePlaybackIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/10/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import AppIntents
import BookPlayerKit
import Foundation

@available(macOS 14.0, watchOS 10.0, *)
struct PausePlaybackIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "intent_playback_pause_title"

  func perform() async throws -> some IntentResult {
    let coreServices = try await AppServices.shared.awaitCoreServices()
    await MainActor.run {
      coreServices.playerLoaderService.playerManager.pause()
    }

    return .result()
  }
}
