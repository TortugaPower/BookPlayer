//
//  CompleteAccountCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import UIKit

class CompleteAccountCoordinator: Coordinator, AlertPresenter {
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
    let viewModel = CompleteAccountViewModel(
      accountService: self.accountService,
      account: self.accountService.getAccount()!
    )

    let vc = UIHostingController(rootView: CompleteAccountView(viewModel: viewModel))
    viewModel.onTransition = { route in
      switch route {
      case .success:
        self.showCongrats()
      case .link(let url):
        self.openLink(url)
      case .dismiss:
        self.flow.finishPresentation(animated: true)
      case .showLoader(let flag):
        if flag {
          self.showLoader()
        } else {
          self.stopLoader()
        }
      }
    }

    flow.startPresentation(vc, animated: true)
  }

  func showCongrats() {
    flow.navigationController.getTopViewController()?.view.startConfetti()
    flow.navigationController.showAlert("pro_welcome_title".localized, message: "pro_welcome_description".localized) { [weak self] in
      self?.flow.finishPresentation(animated: true)
    }
  }

  func openLink(_ url: URL) {
    UIApplication.shared.open(url)
  }

  func showError(_ error: Error) {
    flow.navigationController.showAlert("error_title".localized, message: error.localizedDescription)
  }
}
