//
//  MiniPlayerCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

class MiniPlayerCoordinator: Coordinator {
  var childCoordinators = [Coordinator]()
  var navigationController: UINavigationController
  weak var parentCoordinator: MainCoordinator!

  let playerManager: PlayerManager

  init(navigationController: UINavigationController,
       parentCoordinator: MainCoordinator,
       playerManager: PlayerManager) {
    self.navigationController = navigationController
    self.playerManager = playerManager
    self.parentCoordinator = parentCoordinator
  }

  func start() {
    let miniPlayerVC = MiniPlayerViewController.instantiate(from: .Main)
    miniPlayerVC.coordinator = self
    self.parentCoordinator.rootViewController.addChild(miniPlayerVC)
    self.parentCoordinator.rootViewController.miniPlayerContainer.addSubview(miniPlayerVC.view)
    miniPlayerVC.didMove(toParent: self.parentCoordinator.rootViewController)
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      navigationController: self.navigationController,
      playerManager: self.playerManager
    )
    playerCoordinator.parentCoordinator = self.parentCoordinator
    self.parentCoordinator.childCoordinators.append(playerCoordinator)
    playerCoordinator.start()
  }
}
