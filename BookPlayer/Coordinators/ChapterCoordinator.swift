//
//  ChapterCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class ChapterCoordinator: Coordinator {
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
    let viewModel = ChaptersViewModel(playerManager: playerManager)
    viewModel.onTransition = { routes in
      switch routes {
      case .dismiss:
        self.flow.finishPresentation(animated: true)
      }
    }
    let vc = ChaptersViewController.instantiate(from: .Player)
    vc.viewModel = viewModel

    flow.startPresentation(vc, animated: true)
  }
}
