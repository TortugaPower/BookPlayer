//
//  Constants.swift
//  BookPlayer

import Foundation

public enum Constants {
    public enum UserDefaults: String {
        // Application information
        case completedFirstLaunch = "userSettingsCompletedFirstLaunch"
        case lastPauseTime = "userSettingsLastPauseTime"
        case lastPlayedItem = "userSettingsLastPlayedItem"
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
        case iCloudBackupsEnabled = "userSettingsiCloudBackupsEnabled"
        case autolockDisabled = "userSettingsDisableAutolock"
        case autolockDisabledOnlyWhenPowered = "userSettingsAutolockOnlyWhenPowered"
        case playerListPrefersBookmarks = "userSettingsPlayerListPrefersBookmarks"

        case rewindInterval = "userSettingsRewindInterval"
        case forwardInterval = "userSettingsForwardInterval"

      // One-time migrations
      case fileProtectionMigration = "userFileProtectionMigration"
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
    public static let ApplicationGroupIdentifier = "group.\(Bundle.main.configurationString(for: .bundleIdentifier)).files"

    public enum DefaultArtworkColors {
        case primary
        case secondary
        case accent
        case separator
        case systemBackground
        case secondarySystemBackground
        case tertiarySystemBackground
        case systemGroupedBackground
        case systemFill
        case secondarySystemFill
        case tertiarySystemFill
        case quaternarySystemFill

        var lightColor: String {
            switch self {
            case .primary:
                return "#37454E"
            case .secondary:
                return "#3488D1"
            case .accent:
                return "#7685B3"
            case .separator:
                return "#DCDCDC"
            case .systemBackground:
                return "#FAFAFA"
            case .secondarySystemBackground:
                return "#FCFBFC"
            case .tertiarySystemBackground:
                return "#E8E7E9"
            case .systemGroupedBackground:
                return "#EFEEF0"
            case .systemFill:
                return "#87A0BA"
            case .secondarySystemFill:
                return "#ACAAB1"
            case .tertiarySystemFill:
                return "#7685B3"
            case .quaternarySystemFill:
                return "#7685B3"
            }
        }

        var darkColor: String {
            switch self {
            case .primary:
                return "#EEEEEE"
            case .secondary:
                return "#3488D1"
            case .accent:
                return "#7685B3"
            case .separator:
                return "#434448"
            case .systemBackground:
                return "#050505"
            case .secondarySystemBackground:
                return "#111113"
            case .tertiarySystemBackground:
                return "#333538"
            case .systemGroupedBackground:
                return "#2C2D30"
            case .systemFill:
                return "#647E98"
            case .secondarySystemFill:
                return "#707176"
            case .tertiarySystemFill:
                return "#7685B3"
            case .quaternarySystemFill:
                return "#7685B3"
            }
        }
    }
}
