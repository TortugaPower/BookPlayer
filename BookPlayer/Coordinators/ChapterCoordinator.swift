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
  let playerManager: PlayerManagerProtocol

  init(
    playerManager: PlayerManagerProtocol,
    presentingViewController: UIViewController?
  ) {
    self.playerManager = playerManager

    super.init(
      navigationController: AppNavigationController.instantiate(from: .Player),
      flowType: .modal
    )

    self.presentingViewController = presentingViewController
  }

  override func start() {
    let vc = ChaptersViewController.instantiate(from: .Player)
    let viewModel = ChaptersViewModel(playerManager: self.playerManager)
    viewModel.coordinator = self
    vc.viewModel = viewModel

    self.navigationController.viewControllers = [vc]
    self.navigationController.presentationController?.delegate = self
    self.presentingViewController?.present(self.navigationController, animated: true, completion: nil)
  }
}
