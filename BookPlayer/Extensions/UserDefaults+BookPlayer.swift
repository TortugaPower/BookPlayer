//
//  UserDefaults+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/12/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Foundation

extension UserDefaults {
    @objc dynamic var userSettingsAppIcon: String? {
        return string(forKey: Constants.UserDefaults.appIcon.rawValue)
    }
}
