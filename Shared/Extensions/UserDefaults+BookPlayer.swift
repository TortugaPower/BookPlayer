//
//  UserDefaults+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/11/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation

public extension UserDefaults {
  static var sharedDefaults = UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)!

  @objc dynamic var userSettingsAppIcon: String? {
    return string(forKey: Constants.UserDefaults.appIcon)
  }

  @objc dynamic var userSettingsCrashReportsDisabled: Bool {
    return bool(forKey: Constants.UserDefaults.crashReportsDisabled)
  }

  @objc dynamic var userSettingsAllowCellularData: Bool {
    return bool(forKey: Constants.UserDefaults.allowCellularData)
  }

  @objc dynamic var userSettingsBoostVolume: Bool {
    return bool(forKey: Constants.UserDefaults.boostVolumeEnabled)
  }

  @objc dynamic var userSettingsUpdateProgress: Bool {
    return bool(forKey: Constants.UserDefaults.updateProgress)
  }

  @objc dynamic var userSettingsRewindInterval: TimeInterval {
    return double(forKey: Constants.UserDefaults.rewindInterval)
  }

  @objc dynamic var userSettingsForwardInterval: TimeInterval {
    return double(forKey: Constants.UserDefaults.forwardInterval)
  }
}
