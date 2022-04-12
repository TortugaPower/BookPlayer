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

    super.init(navigationController: navigationController, flowType: .modal)
  }

  override func start() {
    let vc = SettingsViewController.instantiate(from: .Settings)
    vc.viewModel = SettingsViewModel(accountService: self.accountService)
    vc.viewModel.coordinator = self
    self.navigationController.presentationController?.delegate = self

    vc.navigationItem.largeTitleDisplayMode = .never
    // TODO: localize
    self.navigationController.tabBarItem = UITabBarItem(
      title: "Settings",
      image: UIImage(systemName: "gearshape"),
      selectedImage: UIImage(systemName: "gearshape.fill")
    )
    self.presentingViewController = self.navigationController

    if let tabBarController = tabBarController {
      let newControllersArray = (tabBarController.viewControllers ?? []) + [self.navigationController]
      tabBarController.setViewControllers(newControllersArray, animated: false)
    }

    self.navigationController.pushViewController(vc, animated: true)
  }

  func showStorageManagement() {
    let child = StorageCoordinator(
      libraryService: self.libraryService,
      presentingViewController: self.presentingViewController
    )
    self.childCoordinators.append(child)
    child.parentCoordinator = self
    child.start()
  }

  func showPlus() {
    let viewModel = PlusViewModel(accountService: self.accountService)
    viewModel.coordinator = self
    let vc = PlusViewController.instantiate(from: .Settings)
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .never
    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]

    self.navigationController.getTopViewController()?.present(nav, animated: true, completion: nil)
  }

  func showThemes() {
    let viewModel = ThemesViewModel(accountService: self.accountService)
    viewModel.coordinator = self
    let vc = ThemesViewController.instantiate(from: .Settings)
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .never
    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]

    self.navigationController.present(nav, animated: true)
  }

  func showIcons() {
    let viewModel = IconsViewModel(accountService: self.accountService)
    viewModel.coordinator = self
    let vc = IconsViewController.instantiate(from: .Settings)
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .never
    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]

    self.navigationController.present(nav, animated: true)
  }

  func showPlayerControls() {
    let vc = PlayerSettingsViewController.instantiate(from: .Settings)
    vc.navigationItem.largeTitleDisplayMode = .never
    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]

    self.navigationController.present(nav, animated: true)
  }

  func showCredits() {
    let vc = CreditsViewController.instantiate(from: .Settings)
    vc.navigationItem.largeTitleDisplayMode = .never
    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]

    self.navigationController.present(nav, animated: true)
  }
}
