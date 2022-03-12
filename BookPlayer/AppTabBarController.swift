//
//  AppTabBarController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 11/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class AppTabBarController: UITabBarController {
  override func viewDidLoad() {
    setUpTheming()
  }
}

extension AppTabBarController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.tabBar.backgroundColor = theme.systemBackgroundColor
    self.tabBar.tintColor = theme.linkColor
  }
}
