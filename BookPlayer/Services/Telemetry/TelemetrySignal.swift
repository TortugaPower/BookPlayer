//
//  TelemetrySignal.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/4/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import Foundation
import TelemetryClient

enum TelemetrySignal: TelemetrySignalType {
    // MARK: - Screens

    case settingsScreen = "SettingsScreen"
    case libraryScreen = "LibraryScreen"
    case folderScreen = "FolderScreen"
    case playerScreen = "PlayerScreen"
    case chaptersScreen = "ChaptersScreen"
    case themesScreen = "ThemesScreen"
    case appIconsScreen = "AppIconsScreen"
    case playerControlsScreen = "PlayerControlsScreen"
    case rewindIntervalsScreen = "RewindIntervalsScreen"
    case forwardIntervalsScreen = "ForwardIntervalsScreen"
    case githubScreen = "GithubScreen"
    case tipJarScreen = "TipJarScreen"
    case creditsScreen = "CreditsScreen"

    // MARK: - Actions

    // Library
    case editBulkAction = "EditBulkAction"
    case sortAction = "SortAction"
    case moveAction = "MoveAction"
    case deleteAction = "DeleteAction"
    case renameAction = "RenameAction"
    case shareAction = "ShareAction"
    case importAction = "ImportAction"
    // Player
    case playAction = "PlayAction"
    case pauseAction = "PauseAction"
    case rewindAction = "RewindAction"
    case forwardAction = "ForwardAction"
    case scrubProgressAction = "ScrubProgressAction"
    case sleepTimerAction = "SleepTimerAction"
    case chapterAction = "ChapterAction"
    case jumpToStartAction = "JumpToStartAction"
    case markFinishedAction = "MarkFinishedAction"
    // Themes
    case themeAction = "ThemeAction"
    case themeSystemModeAction = "ThemeSystemModeAction"
    case automaticThemeAction = "AutomaticThemeAction"
    case alwaysDarkThemeAction = "AlwaysDarkThemeAction"
    // App Icon
    case appIconAction = "AppIconAction"
    // Player Controls
    case rewindIntervalAction = "RewindIntervalAction"
    case forwardIntervalAction = "ForwardIntervalAction"
    case smartRewindAction = "SmartRewindAction"
    case boostVolumeAction = "BoostVolumeAction"
    case globalSpeedControlAction = "GlobalSpeedControlAction"
    // Settings
    case autoplayLibraryAction = "AutoplayLibraryAction"
    case disableAutolockAction = "DisableAutolockAction"
    case disableAutolockOnPowerAction = "DisableAutolockOnPowerAction"
    case lastPlayedSiriShortcutAction = "LastPlayedSiriShortcutAction"
    case sleepTimerSiriShortcutAction = "SleepTimerSiriShortcutAction"
    case emailSupportAction = "EmailSupportAction"
    case tipAction = "TipAction"
    case restorePurchaseAction = "RestorePurchaseAction"
    // URL schemes
    case urlSchemeAction = "URLSchemeAction"
    // Accessibility
    case magicTapAction = "MagicTapAction"
    // Siri shortcuts
    case lastPlayedShortcut = "LastPlayedShortcut"
}

enum TelemetryParameter: String {
    case isPlaying
}
