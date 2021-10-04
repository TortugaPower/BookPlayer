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
  let dataManager: DataManager
  var currentActivity: NSUserActivity
  var playbackRecord: PlaybackRecord?

  init(dataManager: DataManager) {
    self.dataManager = dataManager

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

    if self.playbackRecord == nil {
      self.playbackRecord = self.dataManager.getPlaybackRecord()
    }

    guard let record = self.playbackRecord else { return }

    guard !Calendar.current.isDate(record.date, inSameDayAs: Date()) else { return }

    self.playbackRecord = self.dataManager.getPlaybackRecord()
  }

  func stopPlaybackActivity() {
    self.currentActivity.resignCurrent()
    self.playbackRecord = nil
  }

  func recordTime() {
    guard let record = self.playbackRecord else { return }

    self.dataManager.recordTime(record)
  }
}
