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

@available(iOS 16.4, macOS 14.0, watchOS 10.0, *)
struct PausePlaybackIntent: AudioStartingIntent, ForegroundContinuableIntent {
  static var title: LocalizedStringResource = "intent_playback_pause_title"

  func perform() async throws -> some IntentResult {
    let stack = try await DatabaseInitializer().loadCoreDataStack()

    guard let appDelegate = await AppDelegate.shared else {
      throw needsToContinueInForegroundError {
        let actionString = CommandParser.createActionString(from: .pause, parameters: [])
        let actionURL = URL(string: actionString)!
        UIApplication.shared.open(actionURL)
      }
    }

    let coreServices = await appDelegate.createCoreServicesIfNeeded(from: stack)

    coreServices.playerManager.pause()

    return .result()
  }
}
