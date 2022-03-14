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
  weak var tabBarController: UITabBarController?

  override func start() {
    let vc = ItemListViewController.instantiate(from: .Main)
    let viewModel = ItemListViewModel(folderRelativePath: nil,
                                      playerManager: self.playerManager,
                                      libraryService: self.libraryService,
                                      themeAccent: ThemeManager.shared.currentTheme.linkColor)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .automatic
    vc.tabBarItem = UITabBarItem(
      title: "library_title".localized,
      image: UIImage(systemName: "books.vertical"),
      selectedImage: UIImage(systemName: "books.vertical.fill")
    )

    self.presentingViewController = self.navigationController
    self.navigationController.pushViewController(vc, animated: true)
    self.navigationController.delegate = self

    if let tabBarController = tabBarController {
      let newControllersArray = (tabBarController.viewControllers ?? []) + [self.navigationController]
      tabBarController.setViewControllers(newControllersArray, animated: false)
    }

    self.loadLastBookIfAvailable()

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
