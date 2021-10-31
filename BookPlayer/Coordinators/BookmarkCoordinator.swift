//
//  BookmarkCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit

class BookmarkCoordinator: Coordinator {
  let playerManager: PlayerManager
  let dataManager: DataManager

  init(navigationController: UINavigationController,
       playerManager: PlayerManager,
       dataManager: DataManager) {
    self.playerManager = playerManager
    self.dataManager = dataManager

    super.init(navigationController: navigationController,
               flowType: .modal)
  }

  override func start() {
    let vc = BookmarksViewController.instantiate(from: .Player)
    let viewModel = BookmarksViewModel(playerManager: self.playerManager,
                                       dataManager: self.dataManager)
    viewModel.coordinator = self
    vc.viewModel = viewModel

    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]
    nav.presentationController?.delegate = self
    self.presentingViewController?.present(nav, animated: true, completion: nil)
  }
}
