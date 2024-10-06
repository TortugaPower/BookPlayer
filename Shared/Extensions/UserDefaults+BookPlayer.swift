//
//  UserDefaults+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/11/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
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
}
