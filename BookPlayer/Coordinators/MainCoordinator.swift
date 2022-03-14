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
  let tabBarController: AppTabBarController

  let playerManager: PlayerManager
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let speedManager: SpeedManagerProtocol
  let watchConnectivityService: WatchConnectivityService
  var carPlayManager: CarPlayManager!

  init(
    navigationController: UINavigationController,
    libraryService: LibraryServiceProtocol
  ) {
    self.libraryService = libraryService
    let playbackService = PlaybackService(libraryService: libraryService)
    self.playbackService = playbackService
    let speedManager = SpeedManager(libraryService: libraryService)
    self.speedManager = speedManager

    let watchService = WatchConnectivityService(libraryService: libraryService, playbackService: playbackService)
    self.watchConnectivityService = watchService
    self.playerManager = PlayerManager(
      libraryService: libraryService,
      playbackService: self.playbackService,
      speedManager: speedManager,
      watchConnectivityService: watchService
    )
    ThemeManager.shared.libraryService = libraryService

    let viewModel = MiniPlayerViewModel(playerManager: self.playerManager)
    self.tabBarController = AppTabBarController(miniPlayerViewModel: viewModel)
    tabBarController.modalPresentationStyle = .fullScreen
    tabBarController.modalTransitionStyle = .crossDissolve

    super.init(navigationController: navigationController, flowType: .modal)
    viewModel.coordinator = self
  }

  override func start() {
    self.presentingViewController = tabBarController

    if let currentTheme = try? self.libraryService.getLibraryCurrentTheme() {
      ThemeManager.shared.currentTheme = SimpleTheme(with: currentTheme)
    }

    let libraryCoordinator = LibraryListCoordinator(
      navigationController: AppNavigationController.instantiate(from: .Main),
      playerManager: self.playerManager,
      speedManager: self.speedManager,
      importManager: ImportManager(libraryService: self.libraryService),
      libraryService: self.libraryService,
      playbackService: self.playbackService
    )
    libraryCoordinator.tabBarController = tabBarController
    libraryCoordinator.parentCoordinator = self
    self.childCoordinators.append(libraryCoordinator)
    libraryCoordinator.start()

    let profileCoordinator = ProfileCoordinator(
      libraryService: self.libraryService,
      navigationController: AppNavigationController.instantiate(from: .Main)
    )
    profileCoordinator.tabBarController = tabBarController
    profileCoordinator.parentCoordinator = self
    self.childCoordinators.append(profileCoordinator)
    profileCoordinator.start()

    self.setupCarPlay()
    self.watchConnectivityService.startSession()

    self.navigationController.present(tabBarController, animated: false)
  }

  private func setupCarPlay() {
    self.carPlayManager = CarPlayManager(libraryService: self.libraryService)
    MPPlayableContentManager.shared().dataSource = self.carPlayManager
    MPPlayableContentManager.shared().delegate = self.carPlayManager
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      navigationController: AppNavigationController.instantiate(from: .Player),
      playerManager: self.playerManager,
      speedManager: self.speedManager,
      libraryService: self.libraryService
    )
    playerCoordinator.parentCoordinator = self
    playerCoordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(playerCoordinator)
    playerCoordinator.start()
  }

  func showMiniPlayer(_ flag: Bool) {
    guard flag else {
      self.tabBarController.animateView(self.tabBarController.miniPlayer, show: flag)
      return
    }

    if self.playerManager.hasLoadedBook() {
      self.tabBarController.animateView(self.tabBarController.miniPlayer, show: flag)
    }
  }

  func hasPlayerShown() -> Bool {
    return self.childCoordinators.contains(where: { $0 is PlayerCoordinator })
  }

  func getLibraryCoordinator() -> LibraryListCoordinator? {
    return self.childCoordinators.first as? LibraryListCoordinator
  }
}
