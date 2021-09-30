//
//  StorageCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 29/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit

class StorageCoordinator: Coordinator {
  let dataManager: DataManager

  init(dataManager: DataManager,
       navigationController: UINavigationController) {
    self.dataManager = dataManager

    super.init(navigationController: navigationController)
  }

  override func start() {
    let vc = StorageViewController.instantiate(from: .Settings)

    let viewModel = StorageViewModel(dataManager: self.dataManager)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    self.presentingViewController = vc
    self.navigationController.pushViewController(vc, animated: true)
  }
}
