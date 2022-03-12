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
    let rootVC = RootViewController.instantiate(from: .Main)
    let dataManager = DataManager(coreDataStack: coreDataStack)
    let coordinator = MainCoordinator(
      rootController: rootVC,
      libraryService: LibraryService(dataManager: dataManager),
      navigationController: AppNavigationController.instantiate(from: .Main)
    )
    rootVC.viewModel = BaseViewModel<MainCoordinator>()
    rootVC.viewModel.coordinator = coordinator
    rootVC.tabBarItem = UITabBarItem(
      title: "library_title".localized,
      image: UIImage(systemName: "books.vertical"),
      selectedImage: UIImage(systemName: "books.vertical.fill")
    )
    coordinator.parentCoordinator = self
    coordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(coordinator)

    let tabBarController = AppTabBarController()
    tabBarController.modalPresentationStyle = .fullScreen
    tabBarController.modalTransitionStyle = .crossDissolve
    tabBarController.viewControllers = [rootVC]

    self.navigationController.present(tabBarController, animated: false) {
      coordinator.start()
    }
  }

  override func getMainCoordinator() -> MainCoordinator? {
    return self.childCoordinators.first as? MainCoordinator
  }
}
