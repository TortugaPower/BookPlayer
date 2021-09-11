//
//  MainCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import DeviceKit
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
  }

  func start() {
    self.rootViewController.addChild(self.navigationController)
    self.rootViewController.mainContainer.addSubview(self.navigationController.view)
    self.navigationController.didMove(toParent: self.rootViewController)

    let child = MiniPlayerCoordinator(navigationController: self.navigationController,
                                            parentCoordinator: self,
                                            playerManager: PlayerManager.shared)
    self.childCoordinators.append(child)
    child.start()

    let loadingVC = LoadingViewController.instantiate(from: .Main)
    loadingVC.coordinator = self

    self.navigationController.viewControllers = [loadingVC]
  }

  func didFinishLoadingSequence() {
    self.showLibrary()
  }

  func showLibrary() {
    let offset: CGFloat = Device.current.hasSensorHousing ? 199: 88

    let library = try? DataManager.getLibrary()
    let libraryCoordinator = LibraryListCoordinator(navigationController: self.navigationController,
                                                    library: library ?? DataManager.createLibrary(),
                                                    miniPlayerOffset: offset,
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
