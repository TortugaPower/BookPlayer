//
//  ProfileCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class ProfileCoordinator: Coordinator {
  weak var tabBarController: UITabBarController?

  let libraryService: LibraryServiceProtocol

  init(
    libraryService: LibraryServiceProtocol,
    navigationController: UINavigationController
  ) {
    self.libraryService = libraryService

    super.init(navigationController: navigationController,
               flowType: .push)
  }

  override func start() {
    let vc = ProfileViewController.instantiate(from: .Profile)
    let viewModel = ProfileViewModel()
    viewModel.coordinator = self
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .never
    // TODO: localize
    self.navigationController.tabBarItem = UITabBarItem(
      title: "Profile",
      image: UIImage(systemName: "person.crop.circle"),
      selectedImage: UIImage(systemName: "person.crop.circle.fill")
    )

    self.presentingViewController = self.navigationController

    if let tabBarController = tabBarController {
      let newControllersArray = (tabBarController.viewControllers ?? []) + [self.navigationController]
      tabBarController.setViewControllers(newControllersArray, animated: false)
    }

    self.navigationController.pushViewController(vc, animated: true)
  }

  func showSettings() {
    let settingsCoordinator = SettingsCoordinator(
      libraryService: self.libraryService,
      navigationController: AppNavigationController.instantiate(from: .Settings)
    )
    settingsCoordinator.parentCoordinator = self
    settingsCoordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(settingsCoordinator)
    settingsCoordinator.start()
  }

  func showAccount() {
    let loginCoordinator = LoginCoordinator(
      presentingViewController: self.presentingViewController
    )

    self.childCoordinators.append(loginCoordinator)
    loginCoordinator.parentCoordinator = self
    loginCoordinator.start()
  }
}
