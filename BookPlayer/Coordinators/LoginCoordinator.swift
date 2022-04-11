//
//  LoginCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 3/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

enum LoginActionRoutes {
  case signedIn(identifier: String, email: String)
}

class LoginCoordinator: Coordinator {
  public var onAction: Transition<ItemListActionRoutes>?

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
    let vc = LoginViewController.instantiate(from: .Profile)
    let viewModel = LoginViewModel(accountService: self.accountService)
    viewModel.coordinator = self
    vc.viewModel = viewModel

    self.navigationController.navigationBar.prefersLargeTitles = false
    self.navigationController.viewControllers = [vc]
    self.navigationController.presentationController?.delegate = self
    self.presentingViewController?.present(self.navigationController, animated: true, completion: nil)
  }

  func showError(_ error: Error) {
    self.navigationController.showAlert("error_title".localized, message: error.localizedDescription)
  }

  func showCompleteAccount() {
    let child = CompleteAccountCoordinator(
      accountService: self.accountService,
      presentingViewController: self.presentingViewController
    )

    self.childCoordinators.append(child)
    child.parentCoordinator = self

    self.presentingViewController?.dismiss(animated: true, completion: { [child] in
      child.start()
    })
  }
}
