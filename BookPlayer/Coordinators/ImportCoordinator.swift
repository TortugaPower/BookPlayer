//
//  ImportCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

class ImportCoordinator: Coordinator {
  let importManager: ImportManager
  weak var importViewController: ImportViewController?

  init(
    importManager: ImportManager,
    presentingViewController: UIViewController?
  ) {
    self.importManager = importManager

    super.init(
      navigationController: AppNavigationController.instantiate(from: .Player),
      flowType: .modal
    )

    self.presentingViewController = presentingViewController
  }

  override func start() {
    let vc = ImportViewController.instantiate(from: .Main)
    self.importViewController = vc
    let viewModel = ImportViewModel(importManager: self.importManager)
    viewModel.coordinator = self
    vc.viewModel = viewModel

    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]
    nav.presentationController?.delegate = self
    AppDelegate.shared?.activeSceneDelegate?.coordinator.getMainCoordinator()?
      .getTopController()?.present(nav, animated: true, completion: nil)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    try? self.importViewController?.viewModel.discardImportOperation()
    super.presentationControllerDidDismiss(presentationController)
  }
}
