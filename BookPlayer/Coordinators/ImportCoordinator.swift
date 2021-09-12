//
//  ImportCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

class ImportCoordinator: Coordinator {
  override func start() {
    let vc = ImportViewController.instantiate(from: .Main)
    vc.coordinator = self

    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]

    self.navigationController.present(nav, animated: true, completion: nil)
    self.presentingViewController = vc
  }
}
