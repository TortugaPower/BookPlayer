//
//  PlayerControlsCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/6/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit

class PlayerControlsCoordinator: Coordinator {
  let flow: BPCoordinatorPresentationFlow
  let playerManager: PlayerManagerProtocol

  init(
    flow: BPCoordinatorPresentationFlow,
    playerManager: PlayerManagerProtocol
  ) {
    self.flow = flow
    self.playerManager = playerManager
  }

  func start() {
    let viewModel = PlayerControlsViewModel(playerManager: self.playerManager)
    viewModel.onTransition = { routes in
      switch routes {
      case .dismiss:
        self.flow.finishPresentation(animated: true)
      }
    }
    let vc = PlayerControlsViewController.instantiate(from: .Player)
    vc.viewModel = viewModel
    flow.startPresentation(vc, animated: true)
  }
}
