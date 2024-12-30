//
//  CustomSleepTimerIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/9/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation
import AppIntents

@available(iOS 16.0, macOS 14.0, watchOS 10.0, tvOS 16.0, *)
struct CustomSleepTimerIntent: AppIntent {
  static var title: LocalizedStringResource = "intent_sleeptimer_set_duration"

  @Parameter(
    title: LocalizedStringResource("duration_title"),
    requestValueDialog: IntentDialog(LocalizedStringResource("intent_sleeptimer_request_duration_title"))
  )
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

