//
//  Constants.swift
//  BookPlayer

import Foundation

struct UserDefaultsConstants {
    // Application information
    static let completedFirstLaunch = "userSettingsCompletedFirstLaunch"
    static let lastPauseTime = "userSettingsLastPauseTime"
    static let lastPlayedBook = "userSettingsLastPlayedBook"

    // User preferences
    static let smartRewindEnabled = "userSettingsSmartRewind"
    static let boostVolumeEnabled = "userSettingsBoostVolume"
    static let globalSpeedEnabled = "userSettingsGlobalSpeed"
    static let autoplayEnabled = "userSettingsAutoplay"

    static let rewindInterval = "userSettingsRewindInterval"
    static let forwardInterval = "userSettingsForwardInterval"
}
