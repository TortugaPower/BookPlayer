//
//  LoginCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 3/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class LoginCoordinator: Coordinator, AlertPresenter {
  enum Routes {
    case completeAccount
  }

  var onFinish: BPTransition<Routes>?

  let flow: BPCoordinatorPresentationFlow
  let accountService: AccountServiceProtocol

  init(
    flow: BPCoordinatorPresentationFlow,
    accountService: AccountServiceProtocol
  ) {
    self.flow = flow
    self.accountService = accountService
  }

  func start() {
    let viewModel = LoginViewModel(accountService: self.accountService)
    viewModel.alertPresenter = self
    viewModel.onTransition = { routes in
      switch routes {
      case .completeAccount:
        self.finish(.completeAccount)
      case .dismiss:
        self.flow.finishPresentation(animated: true)
      }
    }
    let vc = LoginViewController(viewModel: viewModel)
    vc.navigationItem.largeTitleDisplayMode = .never
    flow.startPresentation(vc, animated: true)
  }

  func showError(_ error: Error) {
    flow.navigationController.showAlert("error_title".localized, message: error.localizedDescription)
  }

  func finish(_ route: Routes) {
    flow.finishPresentation(animated: true)
    onFinish?(route)
  }
}
