//
//  LoadingViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class LoadingViewController: UIViewController, Storyboarded, Themeable {
  var coordinator: LoadingCoordinator!

  override func viewDidLoad() {
    setUpTheming()
    self.navigationController?.isNavigationBarHidden = true
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.navigationController?.isNavigationBarHidden = true
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // TODO: Add migration handlers
    self.coordinator.didFinishLoadingSequence()
  }

  func applyTheme(_ theme: Theme) {
    self.view.backgroundColor = theme.systemBackgroundColor
  }
}
