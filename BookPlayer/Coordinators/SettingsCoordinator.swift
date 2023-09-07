//
//  SettingsCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 22/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit
import SwiftUI

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
    let viewModel = SettingsViewModel(accountService: accountService)

    viewModel.onTransition = { route in
      switch route {
      case .pro:
        self.showPro()
      case .themes:
        self.showThemes()
      case .icons:
        self.showIcons()
      case .playerControls:
        self.showPlayerControls()
      case .storageManagement:
        self.showStorageManagement()
      case .deletedFilesManagement:
        self.showCloudDeletedFiles()
      case .tipJar:
        self.showTipJar()
      case .credits:
        self.showCredits()
      }
    }

    let vc = SettingsViewController.instantiate(from: .Settings)
    vc.viewModel = viewModel
    vc.viewModel.coordinator = self
    self.navigationController.presentationController?.delegate = self

    vc.navigationItem.largeTitleDisplayMode = .never
    self.navigationController.tabBarItem = UITabBarItem(
      title: "settings_title".localized,
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
    let viewModel = StorageViewModel(
      libraryService: libraryService,
      folderURL: DataManager.getProcessedFolderURL()
    )

    viewModel.onTransition = { [weak self] route in
      switch route {
      case .showAlert(let title, let message):
        self?.showAlert(title, message: message)
      case .dismiss:
        self?.presentingViewController?.dismiss(animated: true)
      }
    }

    let vc = UIHostingController(rootView: StorageView(viewModel: viewModel))
    let nav = AppNavigationController(rootViewController: vc)
    presentingViewController?.present(nav, animated: true)
  }

  func showCloudDeletedFiles() {
    let viewModel = StorageCloudDeletedViewModel(folderURL: DataManager.getBackupFolderURL())

    viewModel.onTransition = { [weak self] route in
      switch route {
      case .showAlert(let title, let message):
        self?.showAlert(title, message: message)
      case .dismiss:
        self?.presentingViewController?.dismiss(animated: true)
      }
    }

    let vc = UIHostingController(rootView: StorageView(viewModel: viewModel))
    let nav = AppNavigationController(rootViewController: vc)
    presentingViewController?.present(nav, animated: true)
  }

  func showPro() {
    let presentingVC = self.navigationController.getTopViewController()
    let child: Coordinator

    if self.accountService.getAccountId() != nil {
      child = CompleteAccountCoordinator(
        accountService: self.accountService,
        presentingViewController: presentingVC
      )
    } else {
      child = LoginCoordinator(
        accountService: self.accountService,
        presentingViewController: presentingVC
      )
    }

    self.childCoordinators.append(child)
    child.parentCoordinator = self

    child.start()
  }

  func showTipJar() {
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

    viewModel.onTransition = { [weak self] routes in
      switch routes {
      case .showPro:
        self?.showPro()
      }
    }

    let vc = ThemesViewController.instantiate(from: .Settings)
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .never
    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]

    self.navigationController.present(nav, animated: true)
  }

  func showIcons() {
    let viewModel = IconsViewModel(accountService: self.accountService)

    viewModel.onTransition = { [weak self] routes in
      switch routes {
      case .showPro:
        self?.showPro()
      }
    }

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
