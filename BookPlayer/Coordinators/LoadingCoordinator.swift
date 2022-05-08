//
//  LoadingCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class LoadingCoordinator: Coordinator {
  let loadingViewController: LoadingViewController
  var pendingURLActions = [Action]()

  init(
    navigationController: UINavigationController,
    loadingViewController: LoadingViewController
  ) {
    self.loadingViewController = loadingViewController

    super.init(navigationController: navigationController, flowType: .modal)

    self.loadingViewController.modalPresentationStyle = .fullScreen

    let viewModel = LoadingViewModel(dataMigrationManager: DataMigrationManager())
    viewModel.coordinator = self
    self.loadingViewController.viewModel = viewModel
    self.loadingViewController.presentationController?.delegate = self
  }

  override func start() {
    self.navigationController.show(self.loadingViewController, sender: self)
  }

  func didFinishLoadingSequence(coreDataStack: CoreDataStack) {
    let dataManager = DataManager(coreDataStack: coreDataStack)
    let accountService = AccountService(dataManager: dataManager)
    let libraryService = LibraryService(dataManager: dataManager)
    let coordinator = MainCoordinator(
      navigationController: self.navigationController,
      libraryService: libraryService,
      accountService: accountService,
      syncService: SyncService(libraryService: libraryService)
    )
    coordinator.parentCoordinator = self
    coordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(coordinator)

    coordinator.start()
  }

  override func getMainCoordinator() -> MainCoordinator? {
    return self.childCoordinators.first as? MainCoordinator
  }
}
