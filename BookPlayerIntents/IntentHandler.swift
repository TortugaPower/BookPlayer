//
//  IntentHandler.swift
//  BookPlayerIntents
//
//  Created by Gianni Carlo on 4/12/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Intents

class IntentHandler: INExtension {
  override func handler(for intent: INIntent) -> Any {
    // This is the default implementation.  If you want different objects to handle different intents,
    // you can override this and return the handler you want for that particular intent.
    
    if intent is SleepTimerIntent {
      return SleepTimerHandler()
    }
    
    return PlayMediaIntentHandler()
  }
}
