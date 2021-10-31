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
    self.navigationController.delegate = self
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

  override func interactiveDidFinish(vc: UIViewController) {
    guard let vc = vc as? ItemListViewController else { return }

    vc.viewModel.coordinator.detach()
  }
}
