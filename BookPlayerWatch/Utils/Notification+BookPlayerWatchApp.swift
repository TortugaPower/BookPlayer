//
//  Notification+BookPlayerWatchA[[.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 5/4/19.
//  Copyright © 2019 BookPlayer LLC. All rights reserved.
//

import Foundation

extension Notification.Name {
  public static let lastBook = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).watch.lastBook")
  public static let theme = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).watch.theme")
}
