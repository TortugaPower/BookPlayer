//
//  ButtonFreeCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 2/9/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import UIKit
import BookPlayerKit

class ButtonFreeCoordinator: Coordinator {
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol
  let flow: BPCoordinatorPresentationFlow

  init(
    flow: BPCoordinatorPresentationFlow,
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
    let viewModel = ButtonFreeViewModel(
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
    let vc = ButtonFreeViewController(viewModel: viewModel)
    flow.startPresentation(vc, animated: true)
  }
}
