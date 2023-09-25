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
  
  var flow: BPCoordinatorPresentationFlow {
    return modalOnlyFlow
  }

  let modalOnlyFlow: BPModalOnlyPresentationFlow

  weak var alert: UIAlertController?

  private var disposeBag = Set<AnyCancellable>()

  deinit {
    self.handleAutolockStatus(forceDisable: true)
  }

  init(
    flow: BPModalOnlyPresentationFlow,
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.modalOnlyFlow = flow
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
  }

  func start() {
    let vc = PlayerViewController.instantiate(from: .Player)
    let viewModel = PlayerViewModel(
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    viewModel.onTransition = { routes in
      switch routes {
      case .dismiss:
        self.flow.finishPresentation(animated: true)
      }
    }
    viewModel.coordinator = self
    vc.viewModel = viewModel

    flow.startPresentation(vc, animated: true)

    self.bindGeneralObservers()
    self.handleAutolockStatus()
  }

  func showBookmarks() {
    let bookmarksCoordinator = BookmarkCoordinator(
      flow: .modalFlow(presentingController: modalOnlyFlow.presentedController),
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    bookmarksCoordinator.start()
  }

  func showButtonFree() {
    let coordinator = ButtonFreeCoordinator(
      flow: .modalFlow(presentingController: modalOnlyFlow.presentedController, modalPresentationStyle: .overFullScreen),
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    coordinator.start()
  }

  func showChapters() {
    let chaptersCoordinator = ChapterCoordinator(
      flow: .modalFlow(presentingController: modalOnlyFlow.presentedController),
      playerManager: self.playerManager
    )
    chaptersCoordinator.start()
  }

  func showControls() {
    let playerControlsCoordinator = PlayerControlsCoordinator(
      flow: .modalFlow(presentingController: modalOnlyFlow.presentedController, prefersMediumDetent: true),
      playerManager: playerManager
    )
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
