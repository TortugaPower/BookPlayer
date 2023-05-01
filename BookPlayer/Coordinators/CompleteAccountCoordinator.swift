//
//  CompleteAccountCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class CompleteAccountCoordinator: Coordinator {
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
    let vc = CompleteAccountViewController()
    let viewModel = CompleteAccountViewModel(
      accountService: self.accountService,
      account: self.accountService.getAccount()!
    )
    viewModel.coordinator = self
    vc.viewModel = viewModel

    viewModel.onTransition = { [weak self] route in
      switch route {
      case .success:
        self?.showCongrats()
      case .link(let url):
        self?.openLink(url)
      }
    }

    self.navigationController.navigationBar.prefersLargeTitles = false
    self.navigationController.viewControllers = [vc]
    self.navigationController.presentationController?.delegate = self
    self.presentingViewController?.present(self.navigationController, animated: true, completion: nil)
  }

  func showCongrats() {
    self.navigationController.getTopViewController()?.view.startConfetti()
    self.navigationController.showAlert("pro_welcome_title".localized, message: "pro_welcome_description".localized) { [weak self] in
      self?.didFinish()
    }
  }

  func openLink(_ url: URL) {
    UIApplication.shared.open(url)
  }

  func showError(_ error: Error) {
    self.navigationController.showAlert("error_title".localized, message: error.localizedDescription)
  }
}
