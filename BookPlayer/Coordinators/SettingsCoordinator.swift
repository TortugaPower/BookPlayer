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

  init(dataManager: DataManager,
       navigationController: UINavigationController) {
    self.dataManager = dataManager

    super.init(navigationController: navigationController)
  }

  override func start() {
    let vc = SettingsViewController.instantiate(from: .Settings)
    vc.coordinator = self
    self.navigationController.viewControllers = [vc]
    self.navigationController.presentationController?.delegate = self
    self.presentingViewController?.present(self.navigationController, animated: true, completion: nil)
  }

  override func dismiss() {
    self.presentingViewController?.dismiss(animated: true, completion: { [weak self] in
      self?.parentCoordinator?.childDidFinish(self)
    })
  }

  func showStorageManagement() {
    let child = StorageCoordinator(dataManager: self.dataManager,
                                   navigationController: self.navigationController)
    self.childCoordinators.append(child)
    child.parentCoordinator = self
    child.start()
  }
}
