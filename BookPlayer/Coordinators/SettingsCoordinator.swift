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
    self.navigationController.viewControllers = [vc]
    self.navigationController.presentationController?.delegate = self
    self.presentingViewController?.present(self.navigationController, animated: true, completion: nil)
  }

  func showStorageManagement() {
    let child = StorageCoordinator(libraryService: self.libraryService,
                                   navigationController: self.navigationController)
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

    self.navigationController.present(nav, animated: true, completion: nil)
  }

  func showThemes() {
    let viewModel = ThemesViewModel(accountService: self.accountService)
    viewModel.coordinator = self
    let vc = ThemesViewController.instantiate(from: .Settings)
    vc.viewModel = viewModel
    self.navigationController.pushViewController(vc, animated: true)
  }

  func showIcons() {
    let viewModel = IconsViewModel(accountService: self.accountService)
    viewModel.coordinator = self
    let vc = IconsViewController.instantiate(from: .Settings)
    vc.viewModel = viewModel
    self.navigationController.pushViewController(vc, animated: true)
  }
}
