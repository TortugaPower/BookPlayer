//
//  Theme.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

struct ThemeT {
    var isDark: Bool
    var barTintColor: UIColor
    var settingsBackgroundColor: UIColor
    var backgroundColor: UIColor

    var tintColor: UIColor
    var titleColor: UIColor
    var descriptionColor: UIColor

    //Table cell
    var cellColor: UIColor
    var separatorColor: UIColor
    var sectionHeaderTextColor: UIColor

    var statusBarStyle: UIStatusBarStyle {
        return self.isDark ? .lightContent : .default
    }
}

extension ThemeT {
    static let light = ThemeT(isDark: false,
                              barTintColor: .white,
                              settingsBackgroundColor: UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1.0),
                              backgroundColor: .white,
                              tintColor: .tintColor,
                              titleColor: .textColor,
                              descriptionColor: .lightGray,
                              cellColor: .white,
                              separatorColor: UIColor(red: 0.79, green: 0.78, blue: 0.80, alpha: 1.0),
                              sectionHeaderTextColor: UIColor(red: 0.43, green: 0.43, blue: 0.45, alpha: 1.0))

    static let dark = ThemeT(isDark: true,
                             barTintColor: .black,
                             settingsBackgroundColor: UIColor(white: 0.2, alpha: 1),
                             backgroundColor: UIColor(white: 0.2, alpha: 1),
                             tintColor: .white,
                             titleColor: .white,
                             descriptionColor: .lightGray,
                             cellColor: .darkGray,
                             separatorColor: UIColor(red: 0.79, green: 0.78, blue: 0.80, alpha: 1.0),
                             sectionHeaderTextColor: .white)

    static let sepia = ThemeT(isDark: false,
                              barTintColor: UIColor(hex: "FEF6E1"),
                              settingsBackgroundColor: UIColor(hex: "DAD2C0"),
                              backgroundColor: UIColor(hex: "DAD2C0"),
                              tintColor: UIColor(hex: "BC8800"),
                              titleColor: UIColor(hex: "616161"),
                              descriptionColor: UIColor(hex: "908E87"),
                              cellColor: UIColor(hex: "EFE8D3"),
                              separatorColor: UIColor(hex: "C9C4B9"),
                              sectionHeaderTextColor: UIColor(hex: "616161"))
}
