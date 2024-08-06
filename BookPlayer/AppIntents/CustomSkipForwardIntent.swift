//
//  CustomSkipForwardIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 29/7/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import AppIntents

@available(iOS 16.4, macOS 14.0, watchOS 10.0, tvOS 16.0, *)
struct CustomSkipForwardIntent: AudioStartingIntent, ForegroundContinuableIntent {
  static var title: LocalizedStringResource = "intent_custom_skipforward_title"

  @Parameter(
    title: LocalizedStringResource("intent_custom_interval_title"),
    requestValueDialog: IntentDialog(LocalizedStringResource("intent_custom_skip_request_title"))
  )
  var interval: Measurement<UnitDuration>

  static var parameterSummary: some ParameterSummary {
    Summary("Skip forward \(\.$interval)")
  }

  func perform() async throws -> some IntentResult {
    let seconds = interval.converted(to: .seconds).value
    let stack = try await DatabaseInitializer().loadCoreDataStack()

    let continuation: (@MainActor () async throws -> Void) = {
      let actionString = CommandParser.createActionString(
        from: .skipForward,
        parameters: [URLQueryItem(name: "interval", value: "\(seconds)")]
      )
      let actionURL = URL(string: actionString)!
      UIApplication.shared.open(actionURL)
    }

    guard let appDelegate = await AppDelegate.shared else {
      throw needsToContinueInForegroundError(continuation: continuation)
    }

    let coreServices = await appDelegate.createCoreServicesIfNeeded(from: stack)

    guard coreServices.playerManager.hasLoadedBook() else {
      throw needsToContinueInForegroundError(continuation: continuation)
    }

    coreServices.playerManager.skip(seconds)

    return .result()
  }
}
