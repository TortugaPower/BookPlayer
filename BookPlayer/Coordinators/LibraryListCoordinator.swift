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
    let vc = ItemListViewController.instantiate(from: .Main)
    let viewModel = FolderListViewModel(folder: nil,
                                        library: self.library,
                                        player: self.playerManager,
                                        dataManager: self.dataManager,
                                        theme: ThemeManager.shared.currentTheme)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .automatic
    self.presentingViewController = vc
    self.navigationController.pushViewController(vc, animated: true)

    if let book = self.library.lastPlayedBook {
      self.loadLastBook(book)
    }

    if let mainCoordinator = self.getMainCoordinator(),
       let loadingCoordinator = mainCoordinator.parentCoordinator as? LoadingCoordinator {
      for action in loadingCoordinator.pendingURLActions {
        ActionParserService.handleAction(action)
      }
    }
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

    if let folderViewController = fromViewController as? ItemListViewController {
      folderViewController.viewModel.coordinator.detach()
    }
  }
}
