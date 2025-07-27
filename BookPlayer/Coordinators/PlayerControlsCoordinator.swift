//
//  PlayerControlsCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/6/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import UIKit
import BookPlayerKit
import SwiftUI

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
      case .more:
        self.showMoreControls()
      }
    }
    let vc = PlayerControlsViewController.instantiate(from: .Player)
    vc.viewModel = viewModel
    flow.startPresentation(vc, animated: true)
  }

  func showMoreControls() {
    let vc = UIHostingController(rootView: SettingsPlayerControlsView())
    vc.navigationItem.largeTitleDisplayMode = .never
    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]

    flow.navigationController.present(nav, animated: true)
  }
}
