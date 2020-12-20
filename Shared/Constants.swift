//
//  Constants.swift
//  BookPlayer

import Foundation

public enum Constants {
    public enum UserDefaults: String {
        // Application information
        case completedFirstLaunch = "userSettingsCompletedFirstLaunch"
        case lastPauseTime = "userSettingsLastPauseTime"
        case lastPlayedBook = "userSettingsLastPlayedBook"
        case appIcon = "userSettingsAppIcon"
        case donationMade = "userSettingsDonationMade"
        case showPlayer = "userSettingsShowPlayer"

        // User preferences
        case themeBrightnessEnabled = "userSettingsBrightnessEnabled"
        case themeBrightnessThreshold = "userSettingsBrightnessThreshold"
        case themeDarkVariantEnabled = "userSettingsThemeDarkVariant"
        case systemThemeVariantEnabled = "userSettingsSystemThemeVariant"
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
    }

    public enum SmartRewind: TimeInterval {
        case threshold = 599.0 // 599 = 10 mins
        case maxTime = 30.0
    }

    public enum Volume: Float {
        case normal = 1.0
        case boosted = 2.0
    }

    public static let UserActivityPlayback = Bundle.main.bundleIdentifier! + ".activity.playback"
    public static let ApplicationGroupIdentifier = "group.com.tortugapower.audiobookplayer.files"

    public enum DefaultArtworkColors {
        case background
        case primary
        case secondary
        case highlight

        var lightColor: String {
            switch self {
            case .background:
                return "#FAFAFA"
            case .primary:
                return "#37454E"
            case .secondary:
                return "#3488D1"
            case .highlight:
                return "#7685B3"
            }
        }

        var darkColor: String {
            switch self {
            case .background:
                return "#050505"
            case .primary:
                return "#EEEEEE"
            case .secondary:
                return "#3488D1"
            case .highlight:
                return "#7685B3"
            }
        }
    }
}
