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

@available(iOS 16.0, macOS 14.0, watchOS 10.0, *)
struct LastBookStartPlaybackIntent: AudioStartingIntent {
  static var title: LocalizedStringResource = "Cancel Sleep Timer"

  func perform() async throws -> some IntentResult {
    let stack = try await DatabaseInitializer().loadCoreDataStack()
    
    guard let appDelegate = await AppDelegate.shared else {
      throw "AppDelegate is not available"
    }

    let coreServices = await appDelegate.createCoreServicesIfNeeded(from: stack)

    guard let book = coreServices.libraryService.getLastPlayedItems(limit: 1)?.first else {
      throw "There's no last played book"
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
