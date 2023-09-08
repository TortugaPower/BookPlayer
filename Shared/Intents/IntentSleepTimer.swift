//
//  IntentSleepTimer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/9/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import AppIntents

@available(iOS 16.0, macOS 14.0, watchOS 10.0, *)
struct IntentSleepTimer: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
  static let intentClassName = "SleepTimerIntent"

  static var title: LocalizedStringResource = "Sleep Timer"
  static var description = IntentDescription("Set a sleep timer")

  @Parameter(title: "Predefined Options", default: .fiveMinutes)
  var option: TimerOptionAppEnum

  @Parameter(title: "Seconds")
  var seconds: Int?

  static var parameterSummary: some ParameterSummary {
    Summary("Set Sleep Timer: \(\.$seconds) or \(\.$option)")
  }

  static var predictionConfiguration: some IntentPredictionConfiguration {
    IntentPrediction(parameters: (\.$seconds)) { seconds in
      DisplayRepresentation(
        title: "Set Timer: \(seconds!)",
        subtitle: ""
      )
    }
    IntentPrediction(parameters: (\.$option)) { option in
      DisplayRepresentation(
        title: "Set Timer: \(option)",
        subtitle: ""
      )
    }
  }

  func perform() async throws -> some IntentResult {
    // TODO: Place your refactored intent handler code here.
    return .result()
  }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
fileprivate extension IntentDialog {
  static var optionParameterPrompt: Self {
    "Set Sleep Timer"
  }
  static var optionParameterDisambiguationSelection: Self {
    "Select an option:"
  }
  static func optionParameterConfirmation(option: TimerOptionAppEnum) -> Self {
    "Just to confirm, you wanted ‘\(option)’?"
  }
  static func secondsParameterPrompt(seconds: Int) -> Self {
    "Set \(seconds)"
  }
  static func secondsParameterConfirmation(seconds: Int) -> Self {
    "Just to confirm, you wanted ‘\(seconds)’?"
  }
  static var responseSuccess: Self {
    "The sleep timer was configured"
  }
  static var responseFailure: Self {
    "Error configuring the sleep timer"
  }
}

