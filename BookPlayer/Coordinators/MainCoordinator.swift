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
import Themeable
import UIKit

class MainCoordinator: Coordinator {
  let rootViewController: RootViewController
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let watchConnectivityService: PhoneWatchConnectivityService

  init(
    rootController: RootViewController,
    coreServices: CoreServices,
    navigationController: UINavigationController
  ) {
    self.rootViewController = rootController
    self.libraryService = coreServices.libraryService
    self.playbackService = coreServices.playbackService
    self.playerManager = coreServices.playerManager
    self.watchConnectivityService = coreServices.watchService

    ThemeManager.shared.libraryService = libraryService

    super.init(navigationController: navigationController, flowType: .modal)

    setUpTheming()
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
    // Only animate if it toggles the state
    guard flag != self.rootViewController.isMiniPlayerVisible else { return }

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

  func getTopController() -> UIViewController? {
    return getPresentingController(coordinator: self)
  }

  func getPresentingController(coordinator: Coordinator) -> UIViewController? {
    guard let lastCoordinator = coordinator.childCoordinators.last else {
      return coordinator.presentingViewController?.getTopViewController()
      ?? coordinator.navigationController
    }

    return getPresentingController(coordinator: lastCoordinator)
  }
}

extension MainCoordinator: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    guard
      !UserDefaults.standard.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue)
    else { return }
    // This fixes native components like alerts having the proper color theme
    SceneDelegate.shared?.window?.overrideUserInterfaceStyle = theme.useDarkVariant
    ? .dark
    : .light
  }
}
