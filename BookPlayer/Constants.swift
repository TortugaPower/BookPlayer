//
//  Constants+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Foundation

enum Constants {
    enum UserDefaults: String {
        // Application information
        case completedFirstLaunch = "userSettingsCompletedFirstLaunch"
        case appGroupsMigration = "userSettingsAppGroupsMigration"
        case lastPauseTime = "userSettingsLastPauseTime"
        case lastPlayedBook = "userSettingsLastPlayedBook"
        case appIcon = "userSettingsAppIcon"
        case donationMade = "userSettingsDonationMade"
        case showPlayer = "userSettingsShowPlayer"

        // User preferences
        case themeBrightnessEnabled = "userSettingsBrightnessEnabled"
        case themeBrightnessThreshold = "userSettingsBrightnessThreshold"
        case themeDarkVariantEnabled = "userSettingsThemeDarkVariant"
        case chapterContextEnabled = "userSettingsChapterContext"
        case remainingTimeEnabled = "userSettingsRemainingTime"
        case smartRewindEnabled = "userSettingsSmartRewind"
        case boostVolumeEnabled = "userSettingsBoostVolume"
        case globalSpeedEnabled = "userSettingsGlobalSpeed"
        case autoplayEnabled = "userSettingsAutoplay"
        case autolockDisabled = "userSettingsDisableAutolock"
        case autolockDisabledOnlyWhenPowered = "userSettingsAutolockOnlyWhenPowered"

        case rewindInterval = "userSettingsRewindInterval"
        case forwardInterval = "userSettingsForwardInterval"

        // web bookmark
        case webHomePage = "userSettingsHomePage"
    }

    enum SmartRewind: TimeInterval {
        case threshold = 599.0 // 599 = 10 mins
        case maxTime = 30.0
    }

    enum Volume: Float {
        case normal = 1.0
        case boosted = 2.0
    }

    static let UserActivityPlayback = Bundle.main.bundleIdentifier! + ".activity.playback"
}
