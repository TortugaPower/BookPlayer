//
//  StorageCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 29/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit

class StorageCoordinator: Coordinator {
  let dataManager: DataManager

  init(dataManager: DataManager,
       navigationController: UINavigationController) {
    self.dataManager = dataManager

    super.init(navigationController: navigationController)
  }

  override func start() {
    let vc = StorageViewController.instantiate(from: .Settings)

    let viewModel = StorageViewModel(dataManager: self.dataManager)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    self.navigationController.delegate = self
    self.navigationController.pushViewController(vc, animated: true)
  }

  // Clean up for interactive pop gestures
  override func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
    // Read the view controller we’re moving from.
    guard let fromViewController = navigationController.transitionCoordinator?.viewController(forKey: .from) else {
        return
    }

    // Check whether our view controller array already contains that view controller. If it does it means we’re pushing a different view controller on top rather than popping it, so exit.
    if navigationController.viewControllers.contains(fromViewController) {
        return
    }

    if let storageViewController = fromViewController as? StorageViewController {
      storageViewController.viewModel.coordinator.detach()
    }
  }
}
