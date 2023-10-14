//
//  PausePlaybackIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/10/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import AppIntents
import BookPlayerKit

@available(iOS 16.0, macOS 14.0, watchOS 10.0, *)
struct PausePlaybackIntent: AudioStartingIntent {
  static var title: LocalizedStringResource = "Pause playback"

  func perform() async throws -> some IntentResult {
    let stack = try await DatabaseInitializer().loadCoreDataStack()

    guard let appDelegate = await AppDelegate.shared else {
      throw "AppDelegate is not available"
    }

    let coreServices = await appDelegate.createCoreServicesIfNeeded(from: stack)

    coreServices.playerManager.pause()

    return .result()
  }
}
