//
//  RootViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class RootViewController: UIViewController, UIGestureRecognizerDelegate, Storyboarded {
  @IBOutlet public weak var mainContainer: UIView!
  @IBOutlet public weak var miniPlayerContainer: UIView!

  weak var coordinator: MainCoordinator!

  private var themedStatusBarStyle: UIStatusBarStyle?

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return themedStatusBarStyle ?? super.preferredStatusBarStyle
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    self.miniPlayerContainer.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
    self.miniPlayerContainer.layer.shadowOpacity = 0.18
    self.miniPlayerContainer.layer.shadowRadius = 9.0
    self.miniPlayerContainer.clipsToBounds = false
    self.miniPlayerContainer.isHidden = true
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    self.coordinator.start()

    setUpTheming()
  }
}

extension RootViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.themedStatusBarStyle = theme.useDarkVariant
      ? .lightContent
      : .default
    setNeedsStatusBarAppearanceUpdate()

    self.miniPlayerContainer.layer.shadowColor = theme.primaryColor.cgColor
  }
}
