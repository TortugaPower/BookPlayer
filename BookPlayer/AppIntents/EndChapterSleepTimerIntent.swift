//
//  EndChapterSleepTimerIntent.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/9/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation
import AppIntents

@available(iOS 16.4, macOS 14.0, watchOS 10.0, *)
struct EndChapterSleepTimerIntent: AppIntent {
  static var title: LocalizedStringResource = "intent_sleeptimer_eoc_title"

  func perform() async throws -> some IntentResult {
    SleepTimer.shared.setTimer(.endOfChapter)
    return .result()
  }
}
