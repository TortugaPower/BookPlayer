//
//  LastBookStartPlaybackIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/9/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import AppIntents
import BookPlayerKit

@available(iOS 16.4, macOS 14.0, watchOS 10.0, *)
struct LastBookStartPlaybackIntent: AudioStartingIntent, ForegroundContinuableIntent {
  static var title: LocalizedStringResource = .init("intent_lastbook_play_title", table: "Localizable.strings")

  func perform() async throws -> some IntentResult {
    let stack = try await DatabaseInitializer().loadCoreDataStack()
    
    guard let appDelegate = await AppDelegate.shared else {
      throw needsToContinueInForegroundError {
        let actionString = CommandParser.createActionString(
          from: .play,
          parameters: [URLQueryItem(name: "autoplay", value: "true")]
        )
        let actionURL = URL(string: actionString)!
        UIApplication.shared.open(actionURL)
      }
    }

    let coreServices = await appDelegate.createCoreServicesIfNeeded(from: stack)

    guard let book = coreServices.libraryService.getLastPlayedItems(limit: 1)?.first else {
      throw "intent_lastbook_empty_error".localized
    }

    await appDelegate.loadPlayer(
      book.relativePath,
      autoplay: true,
      showPlayer: nil,
      alertPresenter: VoidAlertPresenter()
    )

    return .result()
  }
}
