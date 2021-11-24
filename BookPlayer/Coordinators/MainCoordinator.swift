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
  let libraryService: LibraryServiceProtocol
  let watchConnectivityService: WatchConnectivityService
  var carPlayManager: CarPlayManager!

  init(
    rootController: RootViewController,
    dataManager: DataManager,
    libraryService: LibraryServiceProtocol,
    navigationController: UINavigationController
  ) {
    self.rootViewController = rootController
    self.dataManager = dataManager
    self.libraryService = libraryService

    let watchService = WatchConnectivityService(dataManager: dataManager,
                                                libraryService: libraryService)
    self.watchConnectivityService = watchService
    self.playerManager = PlayerManager(dataManager: dataManager, watchConnectivityService: watchService)
    ThemeManager.shared.dataManager = dataManager

    super.init(navigationController: navigationController, flowType: .modal)
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

    let library = self.libraryService.getLibrary()

    if let currentTheme = try? self.libraryService.getLibraryCurrentTheme() {
      ThemeManager.shared.currentTheme = SimpleTheme(with: currentTheme)
    }

    let libraryCoordinator = LibraryListCoordinator(
      navigationController: self.navigationController,
      library: library,
      playerManager: self.playerManager,
      importManager: ImportManager(dataManager: self.dataManager),
      dataManager: self.dataManager,
      libraryService: self.libraryService
    )
    libraryCoordinator.parentCoordinator = self
    self.childCoordinators.append(libraryCoordinator)
    libraryCoordinator.start()

    self.setupCarPlay(with: library)
    self.watchConnectivityService.library = library
    self.watchConnectivityService.startSession()
  }

  private func setupCarPlay(with library: Library) {
    self.carPlayManager = CarPlayManager(dataManager: self.dataManager,
                                         libraryService: self.libraryService)
    MPPlayableContentManager.shared().dataSource = self.carPlayManager
    MPPlayableContentManager.shared().delegate = self.carPlayManager
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
    guard flag == true else {
      self.rootViewController.animateView(self.rootViewController.miniPlayerContainer, show: flag)
      return
    }

    if self.playerManager.hasLoadedBook() {
      self.rootViewController.animateView(self.rootViewController.miniPlayerContainer, show: flag)
    }
  }

  func hasPlayerShown() -> Bool {
    return self.childCoordinators.contains(where: { $0 is PlayerCoordinator })
  }

  func getLibraryCoordinator() -> LibraryListCoordinator? {
    return self.childCoordinators.first as? LibraryListCoordinator
  }
}
