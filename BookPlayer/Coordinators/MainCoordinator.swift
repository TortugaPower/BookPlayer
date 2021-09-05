//
//  MainCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

class MainCoordinator: Coordinator {
  var childCoordinators = [Coordinator]()
  var navigationController: UINavigationController

  init(navigationController: UINavigationController) {
    navigationController.isNavigationBarHidden = true
    self.navigationController = navigationController
  }

  func start() {
    let vc = RootViewController.instantiate(from: .Main)
    navigationController.pushViewController(vc, animated: false)
  }
}
