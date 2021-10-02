//
//  MainCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import DeviceKit
import MediaPlayer
import UIKit

class MainCoordinator: Coordinator {
  let rootViewController: RootViewController
  let playerManager: PlayerManager
  let dataManager: DataManager
  let watchConnectivityService: WatchConnectivityService

  init(
    rootController: RootViewController,
    dataManager: DataManager,
    navigationController: UINavigationController
  ) {
    self.rootViewController = rootController
    self.dataManager = dataManager

    let watchService = WatchConnectivityService(dataManager: dataManager)
    self.watchConnectivityService = watchService
    self.playerManager = PlayerManager(dataManager: dataManager, watchConnectivityService: watchService)
    ThemeManager.shared.dataManager = dataManager

    super.init(navigationController: navigationController)
  }

  override func start() {
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

    let library = (try? self.dataManager.getLibrary()) ?? self.dataManager.createLibrary()

    if library.currentTheme != nil {
      ThemeManager.shared.currentTheme = SimpleTheme(with: library.currentTheme)
    }

    let libraryCoordinator = LibraryListCoordinator(
      navigationController: self.navigationController,
      library: library,
      miniPlayerOffset: offset,
      playerManager: self.playerManager,
      importManager: ImportManager(dataManager: self.dataManager),
      dataManager: self.dataManager
    )
    libraryCoordinator.parentCoordinator = self
    self.childCoordinators.append(libraryCoordinator)
    libraryCoordinator.start()

    self.setupCarPlay(with: library)
    self.watchConnectivityService.library = library
    self.watchConnectivityService.startSession()
  }

  private func setupCarPlay(with library: Library) {
    let carPlayManager = CarPlayManager(library: library, dataManager: self.dataManager)
    MPPlayableContentManager.shared().dataSource = carPlayManager
    MPPlayableContentManager.shared().delegate = carPlayManager
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      navigationController: self.navigationController,
      playerManager: self.playerManager,
      dataManager: self.dataManager
    )
    playerCoordinator.parentCoordinator = self
    self.childCoordinators.append(playerCoordinator)
    playerCoordinator.start()
  }

  func showMiniPlayer(_ flag: Bool) {
    self.rootViewController.animateView(self.rootViewController.miniPlayerContainer, show: flag)
  }

  func hasPlayerShown() -> Bool {
    return self.childCoordinators.contains(where: { $0 is PlayerCoordinator })
  }

  func getLibraryCoordinator() -> LibraryListCoordinator? {
    return self.childCoordinators.first as? LibraryListCoordinator
  }
}
