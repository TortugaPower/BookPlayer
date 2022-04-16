//
//  AccountCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class AccountCoordinator: Coordinator {
  let accountService: AccountServiceProtocol

  init(
    accountService: AccountServiceProtocol,
    presentingViewController: UIViewController?
  ) {
    self.accountService = accountService

    super.init(
      navigationController: AppNavigationController.instantiate(from: .Main),
      flowType: .modal
    )

    self.presentingViewController = presentingViewController
  }

  override func start() {
    let vc = AccountViewController.instantiate(from: .Profile)
    let viewModel = AccountViewModel(accountService: self.accountService)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .never

    self.navigationController.navigationBar.prefersLargeTitles = false
    self.navigationController.viewControllers = [vc]
    self.navigationController.presentationController?.delegate = self
    self.presentingViewController?.present(self.navigationController, animated: true, completion: nil)
    self.presentingViewController = self.navigationController
  }

  func showCompleteAccount() {
    let child = CompleteAccountCoordinator(
      accountService: self.accountService,
      presentingViewController: self.presentingViewController
    )

    self.childCoordinators.append(child)
    child.parentCoordinator = self
    child.start()
  }

  func showError(_ error: Error) {
    self.navigationController.showAlert("error_title".localized, message: error.localizedDescription)
  }
}
