//
//  TimeListenedConfigurationIntent.swift
//  BookPlayerWidgetsPhone
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AppIntents
import Foundation

/// The Time Listened widget's settings: what a tap on it does. Replaces the SiriKit
/// `PlayAndSleepActionIntent`, so widgets set up with it keep their settings: the system maps them
/// here by `intentClassName`, and their values by parameter name and type, so `sleepTimer` and
/// `autoplay` must keep both
struct TimeListenedConfigurationIntent: WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
  static let intentClassName = "PlayAndSleepActionIntent"

  static var title: LocalizedStringResource = "Time Listened"

  @Parameter(title: "settings_siri_sleeptimer_title", default: .cancel)
  var sleepTimer: SleepTimerOption?

  @Parameter(title: "widget_autoplay_title", default: true)
  var autoplay: Bool?
}
