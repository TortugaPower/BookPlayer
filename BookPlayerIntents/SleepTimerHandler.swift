//
//  SleepTimerHandler.swift
//  BookPlayerIntents
//
//  Created by Gianni Carlo on 4/12/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

class SleepTimerHandler: NSObject, SleepTimerIntentHandling {
    func handle(intent: SleepTimerIntent, completion: @escaping (SleepTimerIntentResponse) -> Void) {
        completion(SleepTimerIntentResponse(code: .continueInApp, userActivity: nil))
    }

    @available(iOSApplicationExtension 13.0, *)
    func resolveOption(for intent: SleepTimerIntent, with completion: @escaping (TimerOptionResolutionResult) -> Void) {
        if intent.option == .unknown {
            completion(TimerOptionResolutionResult.needsValue())
        } else {
            completion(TimerOptionResolutionResult.success(with: intent.option))
        }
    }

    @available(iOSApplicationExtension 13.0, *)
    func resolveSeconds(for intent: SleepTimerIntent, with completion: @escaping (SleepTimerSecondsResolutionResult) -> Void) {
        completion(SleepTimerSecondsResolutionResult.notRequired())
    }
}
