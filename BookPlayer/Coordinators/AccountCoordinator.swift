//
//  AccountCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import UIKit

class AccountCoordinator: Coordinator, AlertPresenter {
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
    let vc = AccountViewController()
    let viewModel = AccountViewModel(accountService: self.accountService)
    viewModel.coordinator = self
    viewModel.onTransition = { routes in
      switch routes {
      case .dismiss:
        self.flow.finishPresentation(animated: true)
      }
    }
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .never

    flow.startPresentation(vc, animated: true)
  }

  func showCompleteAccount() {
//    let child = CompleteAccountCoordinator(
//      flow: .modalFlow(presentingController: flow.navigationController, prefersMediumDetent: true),
//      accountService: self.accountService
//    )
//    child.start()
  }

  func showUploadedFiles() { }

  func showError(_ error: Error) {
    flow.navigationController.showAlert("error_title".localized, message: error.localizedDescription)
  }

  func showDeleteAccountAlert(onAction: @escaping () -> Void) {
    let alert = UIAlertController(title: "Delete Account",
                                  message: "Warning: this action is not reversible, if your account is deleted, all your synced library details will be deleted from our servers",
                                  preferredStyle: .alert)

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

    alert.addAction(UIAlertAction(title: "delete_button".localized, style: .destructive, handler: { _ in
      onAction()
    }))

    flow.navigationController.present(alert, animated: true, completion: nil)
  }
}
