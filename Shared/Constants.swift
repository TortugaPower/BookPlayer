//
//  Constants.swift
//  BookPlayer

import Foundation

public enum Constants {
    public enum UserDefaults: String {
        // User preferences
        case autoplayEnabled = "userSettingsAutoplay"
        case rewindInterval = "userSettingsRewindInterval"
        case forwardInterval = "userSettingsForwardInterval"
    }

    static let ApplicationGroupIdentifier = "group.com.tortugapower.audiobookplayer.files"

    enum DefaultArtworkColors {
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
