//
//  SettingsCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 22/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit

class SettingsCoordinator: Coordinator {
  let dataManager: DataManager
  let library: Library

  init(dataManager: DataManager,
       library: Library,
       navigationController: UINavigationController) {
    self.dataManager = dataManager
    self.library = library

    super.init(navigationController: navigationController, flowType: .modal)
  }

  override func start() {
    let vc = SettingsViewController.instantiate(from: .Settings)
    vc.viewModel = SettingsViewModel()
    vc.viewModel.coordinator = self
    self.navigationController.viewControllers = [vc]
    self.navigationController.presentationController?.delegate = self
    self.presentingViewController?.present(self.navigationController, animated: true, completion: nil)
  }

  func showStorageManagement() {
    let child = StorageCoordinator(dataManager: self.dataManager,
                                   library: self.library,
                                   navigationController: self.navigationController)
    self.childCoordinators.append(child)
    child.parentCoordinator = self
    child.start()
  }
}
