//
//  CustomSleepTimerIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/9/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import AppIntents

@available(iOS 16.0, macOS 14.0, watchOS 10.0, tvOS 16.0, *)
struct CustomSleepTimerIntent: AppIntent {
  static var title: LocalizedStringResource = "Set Sleep Timer with duration"

  @Parameter(title: "Duration", requestValueDialog: "For how long")
  var duration: Measurement<UnitDuration>

  static var parameterSummary: some ParameterSummary {
    Summary("Set Sleep Timer for \(\.$duration)")
  }

  func perform() async throws -> some IntentResult {
    let seconds = duration.converted(to: .seconds).value
    SleepTimer.shared.setTimer(.countdown(seconds))
    return .result()
  }
}

