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
    let viewModel = ItemListViewModel(folder: nil,
                                      library: self.library,
                                      playerManager: self.playerManager,
                                      libraryService: self.libraryService,
                                      themeAccent: ThemeManager.shared.currentTheme.linkColor)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .automatic
    self.presentingViewController = self.navigationController
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

    self.documentPickerDelegate = vc
  }

  override func interactiveDidFinish(vc: UIViewController) {
    // Coordinator may be already released if popped by VoiceOver gesture
    guard let vc = vc as? ItemListViewController,
          vc.viewModel.coordinator != nil else { return }

    vc.viewModel.coordinator.detach()
  }
}
