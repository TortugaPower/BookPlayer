//
//  UserActivityManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/29/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import Intents

class UserActivityManager {
  let libraryService: LibraryServiceProtocol
  var currentActivity: NSUserActivity

  init(libraryService: LibraryServiceProtocol) {
    self.libraryService = libraryService

    let intent = INPlayMediaIntent()
    let interaction = INInteraction(intent: intent, response: nil)
    interaction.donate(completion: nil)
    let activity = NSUserActivity(activityType: Constants.UserActivityPlayback)
    activity.title = "siri_activity_title".localized
    activity.isEligibleForPrediction = true
    activity.persistentIdentifier = NSUserActivityPersistentIdentifier(Constants.UserActivityPlayback)
    activity.suggestedInvocationPhrase = "siri_invocation_phrase".localized
    activity.isEligibleForSearch = true

    self.currentActivity = activity
  }

  func resumePlaybackActivity() {
    self.currentActivity.becomeCurrent()
  }

  func stopPlaybackActivity() {
    self.currentActivity.resignCurrent()
  }

  func recordTime() {
    self.libraryService.recordTime()
  }
}
