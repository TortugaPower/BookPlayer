//
//  PlayAndSleepActionHandler.swift
//  BookPlayerIntents
//
//  Created by Gianni Carlo on 26/11/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import Intents

class PlayAndSleepActionHandler: NSObject, PlayAndSleepActionIntentHandling {
    func handle(intent: PlayAndSleepActionIntent, completion: @escaping (PlayAndSleepActionIntentResponse) -> Void) {
        completion(PlayAndSleepActionIntentResponse(code: .continueInApp, userActivity: nil))
    }

    @available(iOSApplicationExtension 13.0, *)
    func resolveSleepTimer(for intent: PlayAndSleepActionIntent, with completion: @escaping (TimerOptionResolutionResult) -> Void) {
        if intent.sleepTimer == .unknown {
            completion(TimerOptionResolutionResult.needsValue())
        } else {
            completion(TimerOptionResolutionResult.success(with: intent.sleepTimer))
        }
    }

    @available(iOSApplicationExtension 13.0, *)
    func resolveAutoplay(for intent: PlayAndSleepActionIntent, with completion: @escaping (INBooleanResolutionResult) -> Void) {
        completion(INBooleanResolutionResult.notRequired())
    }
}
