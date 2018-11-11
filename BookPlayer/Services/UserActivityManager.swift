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

    var currentActivity: NSUserActivity

    private init() {
        let activity = NSUserActivity(activityType: Constants.UserActivityPlayback)
        activity.title = "Continue last played book"
        if #available(iOS 12.0, *) {
            activity.isEligibleForPrediction = true
            activity.persistentIdentifier = NSUserActivityPersistentIdentifier(Constants.UserActivityPlayback)
            activity.suggestedInvocationPhrase = "Continue my book"
        }
        activity.isEligibleForSearch = true

        self.currentActivity = activity
    }

    func resumePlaybackActivity() {
        self.currentActivity.becomeCurrent()
    }

    func stopPlaybackActivity() {
        self.currentActivity.resignCurrent()
    }
}
