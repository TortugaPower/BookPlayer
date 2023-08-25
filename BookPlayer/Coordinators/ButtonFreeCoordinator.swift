//
//  ButtonFreeCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 2/9/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit

class ButtonFreeCoordinator: Coordinator {
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol
  
  init(
    navigationController: UINavigationController,
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
    
    super.init(
      navigationController: navigationController,
      flowType: .modal
    )
  }
  
  override func start() {
    let viewModel = ButtonFreeViewModel(
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    viewModel.coordinator = self
    let vc = ButtonFreeViewController(viewModel: viewModel)
    let nav = AppNavigationController(rootViewController: vc)
    nav.modalPresentationStyle = .fullScreen
    self.presentingViewController?.present(nav, animated: true, completion: nil)
    self.presentingViewController = nav
  }
}
