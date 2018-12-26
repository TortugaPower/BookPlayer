//
//  Theme.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

struct Theme {
    var statusBarStyle: UIStatusBarStyle
    var barTintColor: UIColor
    var tintColor: UIColor
    var settingsBackgroundColor: UIColor
    var backgroundColor: UIColor

    var titleColor: UIColor
    var descriptionColor: UIColor

    var selectedColor: UIColor
    var cellColor: UIColor

    var sectionHeaderTextColor: UIColor
}

extension Theme {
    static let light = Theme(statusBarStyle: .default,
                             barTintColor: .white,
                             tintColor: .tintColor,
                             settingsBackgroundColor: UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1.0),
                             backgroundColor: .white,
                             titleColor: .textColor,
                             descriptionColor: .lightGray,
                             selectedColor: .red,
                             cellColor: .white,
                             sectionHeaderTextColor: UIColor(red: 0.43, green: 0.43, blue: 0.45, alpha: 1.0))

    static let dark = Theme(statusBarStyle: .lightContent,
                            barTintColor: .black,
                            tintColor: .white,
                            settingsBackgroundColor: UIColor(white: 0.2, alpha: 1),
                            backgroundColor: UIColor(white: 0.2, alpha: 1),
                            titleColor: .white,
                            descriptionColor: .lightGray,
                            selectedColor: .purple,
                            cellColor: .darkGray,
                            sectionHeaderTextColor: .white)
}
