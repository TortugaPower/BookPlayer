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
    var playbackRecord: PlaybackRecord?

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

        if self.playbackRecord == nil {
            self.playbackRecord = DataManager.getPlaybackRecord()
        }

        guard let record = self.playbackRecord else { return }

        guard !Calendar.current.isDate(record.date, inSameDayAs: Date()) else { return }

        self.playbackRecord = DataManager.getPlaybackRecord()
    }

    func stopPlaybackActivity() {
        self.currentActivity.resignCurrent()
        self.playbackRecord = nil
    }

    func recordTime() {
        guard let record = self.playbackRecord else { return }

        DataManager.recordTime(record)
    }
}
