//
//  LibraryListCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class LibraryListCoordinator: ItemListCoordinator {
  override func start() {
    let vc = LibraryViewController.instantiate(from: .Main)
    vc.coordinator = self
    self.presentingViewController = vc
    self.navigationController.delegate = self
    self.navigationController.pushViewController(vc, animated: false)
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

    if let folderViewController = fromViewController as? FolderListViewController {
      folderViewController.viewModel.coordinator.detach()
    }
  }
}
