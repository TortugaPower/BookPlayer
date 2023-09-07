//
//  PlayMediaIntentHandler.swift
//  BookPlayerIntents
//
//  Created by Gianni Carlo on 4/17/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Intents

class PlayMediaIntentHandler: INExtension, INPlayMediaIntentHandling {
  func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
    let response = INPlayMediaIntentResponse(code: .handleInApp, userActivity: nil)
    completion(response)
  }
}
