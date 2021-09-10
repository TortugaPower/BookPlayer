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
  weak var coordinator: MainCoordinator?

  override func viewDidLoad() {
    setUpTheming()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // TODO: Add migration handlers
    self.coordinator?.didFinishLoadingSequence()
  }

  func applyTheme(_ theme: Theme) {
    self.view.backgroundColor = theme.systemBackgroundColor
  }
}
