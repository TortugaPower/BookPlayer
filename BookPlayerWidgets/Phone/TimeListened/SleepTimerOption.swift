//
//  SleepTimerOption.swift
//  BookPlayerWidgetsPhone
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AppIntents
import Foundation

/// The sleep timers a tap on the Time Listened widget can set. Widgets set up with the SiriKit
/// `TimerOption` migrate by case name, so the cases keep its value names (its `unknown`, no value at
/// all, is `nil` here)
enum SleepTimerOption: String, AppEnum {
  case cancel
  case fiveMinutes
  case tenMinutes
  case fifteenMinutes
  case thirtyMinutes
  case fortyFiveMinutes
  case oneHour
  case endChapter

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "settings_siri_sleeptimer_title"
  static var caseDisplayRepresentations: [SleepTimerOption: DisplayRepresentation] = [
    .cancel: "sleep_off_title",
    .fiveMinutes: "sleeptimer_option_5_minutes",
    .tenMinutes: "sleeptimer_option_10_minutes",
    .fifteenMinutes: "sleeptimer_option_15_minutes",
    .thirtyMinutes: "sleeptimer_option_30_minutes",
    .fortyFiveMinutes: "sleeptimer_option_45_minutes",
    .oneHour: "sleeptimer_option_1_hour",
    .endChapter: "sleep_chapter_option_title",
  ]

  /// The timer as the widget's link encodes it: -1 off, -2 end of chapter
  var seconds: TimeInterval {
    switch self {
    case .cancel: -1
    case .fiveMinutes: 300
    case .tenMinutes: 600
    case .fifteenMinutes: 900
    case .thirtyMinutes: 1800
    case .fortyFiveMinutes: 2700
    case .oneHour: 3600
    case .endChapter: -2
    }
  }
}
