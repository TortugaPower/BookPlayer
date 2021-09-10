//
//  MainCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class MainCoordinator: Coordinator {
  var childCoordinators = [Coordinator]()
  var navigationController: UINavigationController
  let rootViewController: RootViewController

  init(
    rootController: RootViewController,
    navigationController: UINavigationController
  ) {
    self.navigationController = navigationController
    self.rootViewController = rootController
    self.rootViewController.coordinator = self

    self.rootViewController.addChild(self.navigationController)
    self.rootViewController.view.addSubview(self.navigationController.view)
    self.navigationController.didMove(toParent: self.rootViewController)
  }

  func start() {
    let loadingVC = LoadingViewController.instantiate(from: .Main)
    loadingVC.coordinator = self

    self.navigationController.viewControllers = [loadingVC]
  }

  func didFinishLoadingSequence() {
    self.showLibrary()
  }

  func showLibrary() {
    let library = try? DataManager.getLibrary()
    let libraryCoordinator = LibraryListCoordinator(navigationController: self.navigationController,
                                                    library: library ?? DataManager.createLibrary(),
                                                    playerManager: PlayerManager.shared)
    libraryCoordinator.parentCoordinator = self
    self.childCoordinators.append(libraryCoordinator)
    libraryCoordinator.start()
  }

  func childDidFinish(_ child: Coordinator?) {
    guard let index = self.childCoordinators.firstIndex(where: { $0 === child }) else { return }
    self.childCoordinators.remove(at: index)
  }
}
