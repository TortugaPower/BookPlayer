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
  let playerManager: PlayerManagerProtocol
  let accountService: AccountServiceProtocol
  let syncService: SyncServiceProtocol
  
  init(
    libraryService: LibraryServiceProtocol,
    playerManager: PlayerManagerProtocol,
    accountService: AccountServiceProtocol,
    syncService: SyncServiceProtocol,
    navigationController: UINavigationController
  ) {
    self.libraryService = libraryService
    self.playerManager = playerManager
    self.accountService = accountService
    self.syncService = syncService
    
    super.init(navigationController: navigationController,
               flowType: .push)
  }
  
  override func start() {
    let viewModel = ProfileViewModel(
      accountService: accountService,
      libraryService: libraryService,
      playerManager: playerManager,
      syncService: syncService
    )
    
    viewModel.onTransition = { [weak self] route in
      switch route {
      case .showAccount:
        self?.showAccount()
      case .showQueuedTasks:
        self?.showQueuedTasks()
      }
    }
    
    let vc = ProfileViewController(viewModel: viewModel)
    vc.navigationItem.largeTitleDisplayMode = .never
    self.navigationController.tabBarItem = UITabBarItem(
      title: "profile_title".localized,
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
  
  func showQueuedTasks() {
    let viewModel = QueuedSyncTasksViewModel(syncService: syncService)
    
    let vc = QueuedSyncTasksViewController(viewModel: viewModel)
    
    let nav = AppNavigationController(rootViewController: vc)
    self.navigationController.present(nav, animated: true)
  }
}
