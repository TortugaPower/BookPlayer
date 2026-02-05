//
//  LoadingViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class LoadingViewController: UIViewController, MVVMControllerProtocol, Storyboarded, Themeable {
  var viewModel: LoadingViewModel!
  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationController?.isNavigationBarHidden = true
    
    // Subscribe to theme changes to ensure proper initial rendering
    setUpTheming()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.navigationController?.isNavigationBarHidden = true
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    self.viewModel.initializeDataIfNeeded()
  }

  func applyTheme(_ theme: SimpleTheme) {
    self.view.backgroundColor = theme.systemBackgroundColor
  }
  
  override func accessibilityPerformEscape() -> Bool {
      viewModel.dismiss()
      return true
  }
}
