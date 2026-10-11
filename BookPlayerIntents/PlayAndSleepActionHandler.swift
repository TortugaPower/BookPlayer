//
//  PlayAndSleepActionHandler.swift
//  BookPlayerIntents
//
//  Created by Gianni Carlo on 26/11/20.
//  Copyright © 2020 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import Intents

class PlayAndSleepActionHandler: NSObject, PlayAndSleepActionIntentHandling {
  func handle(intent: PlayAndSleepActionIntent, completion: @escaping (PlayAndSleepActionIntentResponse) -> Void) {
    completion(PlayAndSleepActionIntentResponse(code: .continueInApp, userActivity: nil))
  }

  func resolveSleepTimer(for intent: PlayAndSleepActionIntent, with completion: @escaping (TimerOptionResolutionResult) -> Void) {
    if intent.sleepTimer == .unknown {
      completion(TimerOptionResolutionResult.needsValue())
    } else {
      completion(TimerOptionResolutionResult.success(with: intent.sleepTimer))
    }
  }

  func resolveAutoplay(for intent: PlayAndSleepActionIntent, with completion: @escaping (INBooleanResolutionResult) -> Void) {
    completion(INBooleanResolutionResult.notRequired())
  }
}
