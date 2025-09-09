//
//  PlayerCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI
import UIKit

class PlayerCoordinator: Coordinator {
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol

  let flow: BPCoordinatorPresentationFlow

  weak var alert: UIAlertController?
  weak var playerViewController: PlayerViewController!

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
    self.flow = flow
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
  }

  func start() {
    let vc = PlayerViewController.instantiate(from: .Player)
    playerViewController = vc
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
      flow: .modalFlow(presentingController: playerViewController),
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    bookmarksCoordinator.start()
  }

  func showButtonFree() {
    let coordinator = ButtonFreeCoordinator(
      flow: .modalFlow(presentingController: playerViewController, modalPresentationStyle: .overFullScreen),
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    coordinator.start()
  }

  func showChapters() {
    let vc = UIHostingController(
      rootView: ChaptersView {
        ChaptersViewModel(playerManager: self.playerManager)
      }
    )

    playerViewController.present(vc, animated: true)
  }

  func showControls() {
    let playerControlsCoordinator = PlayerControlsCoordinator(
      flow: .modalFlow(presentingController: playerViewController, prefersMediumDetent: true),
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
