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

  @objc dynamic var sharedWidgetActionURL: URL? {
    guard
      let widgetActionString = string(forKey: Constants.UserDefaults.sharedWidgetActionURL)
    else { return nil }

    return URL(string: widgetActionString)
  }

  @objc dynamic var userSettingsAppIcon: String? {
    return string(forKey: Constants.UserDefaults.appIcon)
  }

  @objc dynamic var userSettingsCrashReportsDisabled: Bool {
    return bool(forKey: Constants.UserDefaults.crashReportsDisabled)
  }

  @objc dynamic var userSyncTasksQueue: [Data]? {
    return array(forKey: Constants.UserDefaults.syncTasksQueue) as? [Data]
  }
}
