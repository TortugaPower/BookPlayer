//
//  AccountCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 3/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class AccountCoordinator: Coordinator {
  init(
    navigationController: UINavigationController,
    presentingViewController: UIViewController?
  ) {
    super.init(
      navigationController: navigationController,
      flowType: .modal
    )

    self.presentingViewController = presentingViewController
  }

  override func start() {
    let vc = LoginViewController.instantiate(from: .Profile)
    let viewModel = AccountViewModel()
    viewModel.coordinator = self
    vc.viewModel = viewModel

    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]
    nav.presentationController?.delegate = self
    self.presentingViewController = self.navigationController
    self.presentingViewController?.present(nav, animated: true, completion: nil)
  }
}
