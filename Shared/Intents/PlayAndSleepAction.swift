//
//  PlayAndSleepAction.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/9/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import AppIntents

@available(iOS 16.0, macOS 14.0, watchOS 10.0, *)
struct PlayAndSleepAction: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent, PredictableIntent {
  static let intentClassName = "PlayAndSleepActionIntent"

  static var title: LocalizedStringResource = "Play And Sleep Action"
  static var description = IntentDescription("")

  @Parameter(title: "Timer", default: .cancel)
  var sleepTimer: TimerOptionAppEnum

  @Parameter(title: "Auto-Play", default: true)
  var autoplay: Bool?

  static var parameterSummary: some ParameterSummary {
    Summary()
  }

  static var predictionConfiguration: some IntentPredictionConfiguration {
    IntentPrediction(parameters: (\.$sleepTimer)) { sleepTimer in
      DisplayRepresentation(
        title: "Play last book and sleep in: \(sleepTimer)",
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
  static func sleepTimerParameterDisambiguationIntro(count: Int, sleepTimer: TimerOptionAppEnum) -> Self {
    "There are \(count) options matching ‘\(sleepTimer)’."
  }
  static func sleepTimerParameterConfirmation(sleepTimer: TimerOptionAppEnum) -> Self {
    "Just to confirm, you wanted ‘\(sleepTimer)’?"
  }
  static var autoplayParameterPrompt: Self {
    "Do you want to autoplay the last book?"
  }
  static var responseSuccess: Self {
    "The sleep timer was configured"
  }
  static var responseFailure: Self {
    "Error configuring the sleep timer"
  }
}

