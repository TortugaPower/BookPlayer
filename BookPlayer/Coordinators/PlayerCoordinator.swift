//
//  PlayerCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit

class PlayerCoordinator: Coordinator {
  let playerManager: PlayerManager
  let dataManager: DataManager

  init(navigationController: UINavigationController,
       playerManager: PlayerManager,
       dataManager: DataManager) {
    self.playerManager = playerManager
    self.dataManager = dataManager

    super.init(navigationController: navigationController, flowType: .modal)
  }

  override func start() {
    let vc = PlayerViewController.instantiate(from: .Player)
    let viewModel = PlayerViewModel(playerManager: self.playerManager,
                                    dataManager: self.dataManager)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    self.navigationController.present(vc, animated: true, completion: nil)
    self.presentingViewController = vc
  }

  func showBookmarks() {
    let bookmarksCoordinator = BookmarkCoordinator(navigationController: self.navigationController,
                                                   playerManager: self.playerManager,
                                                   dataManager: self.dataManager)
    bookmarksCoordinator.parentCoordinator = self
    bookmarksCoordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(bookmarksCoordinator)
    bookmarksCoordinator.start()
  }

  func showChapters() {

    let chaptersCoordinator = ChapterCoordinator(navigationController: self.navigationController,
                                                 playerManager: self.playerManager)
    chaptersCoordinator.parentCoordinator = self
    chaptersCoordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(chaptersCoordinator)
    chaptersCoordinator.start()
  }
}
