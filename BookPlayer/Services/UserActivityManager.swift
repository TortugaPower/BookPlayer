//
//  UserActivityManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/29/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation
import Intents

class UserActivityManager {
    static let shared = UserActivityManager()
    private init() {}

    var currentActivity: NSUserActivity?

    private func createPlaybackActivity() -> NSUserActivity {
        let activity = NSUserActivity(activityType: Constants.Activities.playback.rawValue)
        activity.title = "Continue last played book"
        if #available(iOS 12.0, *) {
            activity.isEligibleForPrediction = true
            activity.persistentIdentifier = NSUserActivityPersistentIdentifier(Constants.Activities.playback.rawValue)
            activity.suggestedInvocationPhrase = "Continue my book"
        }
        activity.isEligibleForSearch = true

        return activity
    }

    func resumePlaybackActivity() {
        self.currentActivity = self.currentActivity ?? self.createPlaybackActivity()
        self.currentActivity?.becomeCurrent()
    }

    func stopPlaybackActivity() {
        self.currentActivity?.resignCurrent()
    }
}
