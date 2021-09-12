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
  let rootViewController: RootViewController
  let playerManager = PlayerManager.shared

  init(
    rootController: RootViewController,
    navigationController: UINavigationController
  ) {
    self.rootViewController = rootController

    super.init(navigationController: navigationController)
  }

  override func start() {
    self.presentingViewController = self.rootViewController
    self.rootViewController.addChild(self.navigationController)
    self.rootViewController.mainContainer.addSubview(self.navigationController.view)
    self.navigationController.didMove(toParent: self.rootViewController)

    let miniPlayerVC = MiniPlayerViewController.instantiate(from: .Main)
    let viewModel = MiniPlayerViewModel(playerManager: self.playerManager)
    viewModel.coordinator = self
    miniPlayerVC.viewModel = viewModel

    self.rootViewController.addChild(miniPlayerVC)
    self.rootViewController.miniPlayerContainer.addSubview(miniPlayerVC.view)
    miniPlayerVC.didMove(toParent: self.rootViewController)

    let offset: CGFloat = Device.current.hasSensorHousing ? 199: 88

    let library = try? DataManager.getLibrary()
    let libraryCoordinator = LibraryListCoordinator(
      navigationController: self.navigationController,
      library: library ?? DataManager.createLibrary(),
      miniPlayerOffset: offset,
      playerManager: PlayerManager.shared
    )
    libraryCoordinator.parentCoordinator = self
    self.childCoordinators.append(libraryCoordinator)
    libraryCoordinator.start()
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      navigationController: self.navigationController,
      playerManager: self.playerManager
    )
    playerCoordinator.parentCoordinator = self
    self.childCoordinators.append(playerCoordinator)
    playerCoordinator.start()
  }

  func showMiniPlayer(_ flag: Bool) {
    self.rootViewController.animateView(self.rootViewController.miniPlayerContainer, show: flag)
  }
}
