//
//  UserDefaults+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/11/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation

extension UserDefaults {
  public static var sharedDefaults = UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)!

  @objc public dynamic var sharedWidgetActionURL: URL? {
    guard
      let widgetActionString = string(forKey: Constants.UserDefaults.sharedWidgetActionURL)
    else { return nil }

    return URL(string: widgetActionString)
  }
}
