//
//  SettingsCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 22/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import UIKit

class SettingsCoordinator: Coordinator, AlertPresenter {
  weak var tabBarController: UITabBarController?

  let flow: BPCoordinatorPresentationFlow
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol
  let accountService: AccountServiceProtocol
  let jellyfinConnectionService: JellyfinConnectionService
  let hardcoverService: HardcoverServiceProtocol

  init(
    flow: BPCoordinatorPresentationFlow,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol,
    accountService: AccountServiceProtocol,
    jellyfinConnectionService: JellyfinConnectionService,
    hardcoverService: HardcoverServiceProtocol
  ) {
    self.flow = flow
    self.libraryService = libraryService
    self.syncService = syncService
    self.accountService = accountService
    self.jellyfinConnectionService = jellyfinConnectionService
    self.hardcoverService = hardcoverService
  }

  func start() {
    let viewModel = SettingsViewModel(
      accountService: accountService,
      libraryService: libraryService,
      syncService: syncService,
      jellyfinConnectionService: jellyfinConnectionService
    )

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
      case .autoplay:
        self.showAutoplay()
      case .autolock:
        self.showAutolock()
      case .deletedFilesManagement:
        self.showCloudDeletedFiles()
      }
    }

    let vc = SettingsViewController.instantiate(from: .Settings)
    vc.viewModel = viewModel
    vc.viewModel.coordinator = self

    vc.navigationItem.largeTitleDisplayMode = .never
    flow.navigationController.tabBarItem = UITabBarItem(
      title: "settings_title".localized,
      image: UIImage(systemName: "gearshape"),
      selectedImage: UIImage(systemName: "gearshape.fill")
    )

    if let tabBarController = tabBarController {
      let newControllersArray = (tabBarController.viewControllers ?? []) + [flow.navigationController]
      tabBarController.setViewControllers(newControllersArray, animated: false)
    }

    flow.startPresentation(vc, animated: false)
  }

  func showStorageManagement() {
    let viewModel = StorageViewModel(
      libraryService: libraryService,
      syncService: syncService,
      folderURL: DataManager.getProcessedFolderURL()
    )

    viewModel.onTransition = { [weak self] route in
      switch route {
      case .showAlert(let content):
        self?.flow.navigationController
          .getTopVisibleViewController()?
          .showAlert(content)
      case .dismiss:
        self?.flow.navigationController.dismiss(animated: true)
      }
    }

    let vc = UIHostingController(rootView: StorageView(viewModel: viewModel))
    let nav = AppNavigationController(rootViewController: vc)
    flow.navigationController.present(nav, animated: true)
  }

  func showAutoplay() {
    let viewModel = SettingsAutoplayViewModel()
    viewModel.onTransition = { route in
      switch route {
      case .dismiss:
        self.flow.navigationController.dismiss(animated: true)
      }
    }

    let vc = UIHostingController(rootView: SettingsAutoplayView(viewModel: viewModel))
    let nav = AppNavigationController(rootViewController: vc)
    flow.navigationController.present(nav, animated: true)
  }

  func showAutolock() {
    let viewModel = SettingsAutolockViewModel()
    viewModel.onTransition = { route in
      switch route {
      case .dismiss:
        self.flow.navigationController.dismiss(animated: true)
      }
    }

    let vc = UIHostingController(rootView: SettingsAutolockView(viewModel: viewModel))
    let nav = AppNavigationController(rootViewController: vc)
    flow.navigationController.present(nav, animated: true)
  }

  func showCloudDeletedFiles() {
    let viewModel = StorageCloudDeletedViewModel(folderURL: DataManager.getBackupFolderURL())

    viewModel.onTransition = { [weak self] route in
      switch route {
      case .showAlert(let title, let message):
        self?.showAlert(title, message: message)
      case .dismiss:
        self?.flow.navigationController.dismiss(animated: true)
      }
    }

    let vc = UIHostingController(rootView: StorageCloudDeletedView(viewModel: viewModel))
    let nav = AppNavigationController(rootViewController: vc)
    flow.navigationController.present(nav, animated: true)
  }

  func showPro() {
    let child: Coordinator

    if self.accountService.getAccountId() != nil {
      child = CompleteAccountCoordinator(
        flow: .modalFlow(
          presentingController: flow.navigationController.getTopVisibleViewController()!,
          prefersMediumDetent: true
        ),
        accountService: self.accountService
      )
    } else {
      let loginCoordinator = LoginCoordinator(
        flow: .modalFlow(presentingController: flow.navigationController.getTopVisibleViewController()!),
        accountService: self.accountService
      )
      loginCoordinator.onFinish = { [unowned self] routes in
        switch routes {
        case .completeAccount:
          showCompleteAccount()
        }
      }
      child = loginCoordinator
    }

    child.start()
  }

  func showCompleteAccount() {
    let coordinator = CompleteAccountCoordinator(
      flow: .modalFlow(presentingController: flow.navigationController, prefersMediumDetent: true),
      accountService: self.accountService
    )
    coordinator.start()
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

    flow.navigationController.present(nav, animated: true)
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

    flow.navigationController.present(nav, animated: true)
  }

  func showPlayerControls() {
    let vc = PlayerSettingsViewController.instantiate(from: .Settings)
    vc.navigationItem.largeTitleDisplayMode = .never
    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]

    flow.navigationController.present(nav, animated: true)
  }
}
