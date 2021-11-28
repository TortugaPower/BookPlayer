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
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let watchConnectivityService: WatchConnectivityService
  var carPlayManager: CarPlayManager!

  init(
    rootController: RootViewController,
    libraryService: LibraryServiceProtocol,
    navigationController: UINavigationController
  ) {
    self.rootViewController = rootController
    self.libraryService = libraryService
    self.playbackService = PlaybackService(libraryService: libraryService)

    let watchService = WatchConnectivityService(libraryService: libraryService)
    self.watchConnectivityService = watchService
    self.playerManager = PlayerManager(
      libraryService: libraryService,
      playbackService: self.playbackService,
      speedManager: SpeedManager(libraryService: libraryService),
      watchConnectivityService: watchService
    )
    ThemeManager.shared.libraryService = libraryService

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

    if let currentTheme = try? self.libraryService.getLibraryCurrentTheme() {
      ThemeManager.shared.currentTheme = SimpleTheme(with: currentTheme)
    }

    let libraryCoordinator = LibraryListCoordinator(
      navigationController: self.navigationController,
      playerManager: self.playerManager,
      importManager: ImportManager(libraryService: self.libraryService),
      libraryService: self.libraryService,
      playbackService: self.playbackService
    )
    libraryCoordinator.parentCoordinator = self
    self.childCoordinators.append(libraryCoordinator)
    libraryCoordinator.start()

    self.setupCarPlay()
    self.watchConnectivityService.startSession()
  }

  private func setupCarPlay() {
    self.carPlayManager = CarPlayManager(libraryService: self.libraryService)
    MPPlayableContentManager.shared().dataSource = self.carPlayManager
    MPPlayableContentManager.shared().delegate = self.carPlayManager
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      navigationController: self.navigationController,
      playerManager: self.playerManager,
      libraryService: self.libraryService
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
