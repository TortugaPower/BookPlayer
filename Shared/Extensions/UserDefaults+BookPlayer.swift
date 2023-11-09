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
    return url(forKey: Constants.UserDefaults.sharedWidgetActionURL)
  }
}
