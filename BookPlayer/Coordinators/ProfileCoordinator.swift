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
  let accountService: AccountServiceProtocol

  init(
    libraryService: LibraryServiceProtocol,
    accountService: AccountServiceProtocol,
    navigationController: UINavigationController
  ) {
    self.libraryService = libraryService
    self.accountService = accountService

    super.init(navigationController: navigationController,
               flowType: .push)
  }

  override func start() {
    let vc = ProfileViewController()
    let viewModel = ProfileViewModel(accountService: self.accountService)
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
      accountService: self.accountService,
      navigationController: AppNavigationController.instantiate(from: .Settings)
    )
    settingsCoordinator.parentCoordinator = self
    settingsCoordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(settingsCoordinator)
    settingsCoordinator.start()
  }

  func showAccount() {
    if self.accountService.getAccountId() != nil {
      let child = AccountCoordinator(
        accountService: self.accountService,
        presentingViewController: self.presentingViewController
      )
      self.childCoordinators.append(child)
      child.parentCoordinator = self
      child.start()
    } else {
      let loginCoordinator = LoginCoordinator(
        accountService: self.accountService,
        presentingViewController: self.presentingViewController
      )

      self.childCoordinators.append(loginCoordinator)
      loginCoordinator.parentCoordinator = self
      loginCoordinator.start()
    }
  }
}