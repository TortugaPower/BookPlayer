//
//  IntentHandler.swift
//  BookPlayerIntents
//
//  Created by Gianni Carlo on 4/12/20.
//  Copyright © 2020 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Intents

class IntentHandler: INExtension {
  /// `INPlayMediaIntent` isn't handled here: the app handles it (`application(_:handlerFor:)`)
  override func handler(for intent: INIntent) -> Any {
    if intent is SleepTimerIntent {
      return SleepTimerHandler()
    }

    return self
  }
}
