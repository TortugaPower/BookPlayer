//
//  PlayerCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

class PlayerCoordinator: Coordinator {
  var childCoordinators = [Coordinator]()
  var navigationController: UINavigationController
  weak var parentCoordinator: MainCoordinator?

  let playerManager: PlayerManager

  init(navigationController: UINavigationController,
       playerManager: PlayerManager) {
    self.navigationController = navigationController
    self.playerManager = playerManager
  }

  func start() {
    let vc = PlayerViewController.instantiate(from: .Player)
    vc.coordinator = self
    self.navigationController.present(vc, animated: true, completion: nil)
  }

  func dismiss() {
    self.navigationController.dismiss(animated: true) { [weak self] in
      self?.parentCoordinator?.childDidFinish(self)
    }
  }
}
