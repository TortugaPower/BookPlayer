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
    let vc = AccountViewController()
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

  func showDeleteAccountAlert(onAction: @escaping () -> Void) {
    let alert = UIAlertController(title: "Delete Account",
                                  message: "Warning: this action is not reversible, if your account is deleted, all your synced library details will be deleted from our servers",
                                  preferredStyle: .alert)

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

    alert.addAction(UIAlertAction(title: "delete_button".localized, style: .destructive, handler: { _ in
      onAction()
    }))

    self.navigationController.present(alert, animated: true, completion: nil)
  }
}
