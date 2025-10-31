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
  let playerManager: PlayerManager
  let libraryService: LibraryService
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
    playerManager: PlayerManager,
    libraryService: LibraryService,
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
    let vc = UIHostingController(
      rootView: BookmarksView {
        BookmarksViewModel(
          playerManager: self.playerManager,
          libraryService: self.libraryService,
          syncService: self.syncService
        )
      }
    )

    playerViewController.present(vc, animated: true)
  }

  func showButtonFree() {
    let vc = UIHostingController(
      rootView: ButtonFreeView {
        ButtonFreeViewModel(
          playerManager: self.playerManager,
          libraryService: self.libraryService,
          syncService: self.syncService
        )
      }
    )

    vc.modalPresentationStyle = .overFullScreen
    playerViewController.present(vc, animated: true)
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
    let vc = UIHostingController(
      rootView: PlayerControlsView {
        PlayerControlsViewModel(playerManager: self.playerManager)
      }
    )

    if let sheet = vc.sheetPresentationController {
      sheet.detents = [.medium()]
      sheet.prefersGrabberVisible = true
    }
    
    playerViewController.present(vc, animated: true)
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
