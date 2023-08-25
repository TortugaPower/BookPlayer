//
//  PlayerCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit
import Combine

class PlayerCoordinator: Coordinator {
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol
  weak var alert: UIAlertController?
  
  private var disposeBag = Set<AnyCancellable>()
  
  deinit {
    self.handleAutolockStatus(forceDisable: true)
  }
  
  init(
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol,
    presentingViewController: UIViewController?
  ) {
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
    
    super.init(
      navigationController: AppNavigationController.instantiate(from: .Player),
      flowType: .modal
    )
    
    self.presentingViewController = presentingViewController
  }
  
  override func start() {
    let vc = PlayerViewController.instantiate(from: .Player)
    let viewModel = PlayerViewModel(
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    viewModel.coordinator = self
    vc.viewModel = viewModel
    self.presentingViewController?.present(vc, animated: true, completion: nil)
    self.presentingViewController = vc
    self.bindGeneralObservers()
    self.handleAutolockStatus()
  }
  
  func showBookmarks() {
    let bookmarksCoordinator = BookmarkCoordinator(
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService,
      presentingViewController: self.presentingViewController
    )
    bookmarksCoordinator.parentCoordinator = self
    self.childCoordinators.append(bookmarksCoordinator)
    bookmarksCoordinator.start()
  }
  
  func showButtonFree() {
    let coordinator = ButtonFreeCoordinator(
      navigationController: self.navigationController,
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    coordinator.parentCoordinator = self
    coordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(coordinator)
    coordinator.start()
  }
  
  func showChapters() {
    let chaptersCoordinator = ChapterCoordinator(
      playerManager: self.playerManager,
      presentingViewController: self.presentingViewController
    )
    chaptersCoordinator.parentCoordinator = self
    self.childCoordinators.append(chaptersCoordinator)
    chaptersCoordinator.start()
  }
  
  func showControls() {
    let playerControlsCoordinator = PlayerControlsCoordinator(
      playerManager: self.playerManager,
      presentingViewController: self.presentingViewController
    )
    playerControlsCoordinator.parentCoordinator = self
    self.childCoordinators.append(playerControlsCoordinator)
    playerControlsCoordinator.start()
  }
  
  func bindGeneralObservers() {
    NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
      .debounce(for: 1.0, scheduler: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.handleAutolockStatus()
      }
      .store(in: &disposeBag)
  }
  
  func handleAutolockStatus(forceDisable: Bool = false) {
    guard !forceDisable else {
      UIApplication.shared.isIdleTimerDisabled = false
      UIDevice.current.isBatteryMonitoringEnabled = false
      return
    }
    
    guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled) else {
      UIApplication.shared.isIdleTimerDisabled = false
      UIDevice.current.isBatteryMonitoringEnabled = false
      return
    }
    
    guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabledOnlyWhenPowered) else {
      UIApplication.shared.isIdleTimerDisabled = true
      UIDevice.current.isBatteryMonitoringEnabled = false
      return
    }
    
    if !UIDevice.current.isBatteryMonitoringEnabled {
      UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    UIApplication.shared.isIdleTimerDisabled = UIDevice.current.batteryState != .unplugged
  }
}
