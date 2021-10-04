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

    super.init(navigationController: navigationController)

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
    let rootVC = RootViewController.instantiate(from: .Main)
    let coordinator = MainCoordinator(
      rootController: rootVC,
      dataManager: DataManager(coreDataStack: coreDataStack),
      navigationController: AppNavigationController.instantiate(from: .Main)
    )
    rootVC.coordinator = coordinator
    rootVC.modalPresentationStyle = .fullScreen
    rootVC.modalTransitionStyle = .crossDissolve
    coordinator.parentCoordinator = self
    coordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(coordinator)

    self.navigationController.present(rootVC, animated: true, completion: nil)
  }

  override func dismiss() {
    self.presentingViewController?.dismiss(animated: true, completion: { [weak self] in
      self?.parentCoordinator?.childDidFinish(self)
    })
  }

  override func getMainCoordinator() -> MainCoordinator? {
    return self.childCoordinators.first as? MainCoordinator
  }
}
