//
//  StorageCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 29/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit

class SpeedCoordinator: Coordinator {
  let playerManager: PlayerManagerProtocol

  init(playerManager: PlayerManagerProtocol,
       navigationController: UINavigationController) {
    self.playerManager = playerManager

    super.init(navigationController: navigationController, flowType: .modal)
  }

  override func start() {
    let speedVC = SpeedViewController.instantiate(from: .Player)
    let viewModel = SpeedViewModel(playerManager: self.playerManager)
    viewModel.coordinator = self
    speedVC.viewModel = viewModel

    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [speedVC]
    nav.presentationController?.delegate = self
    nav.modalPresentationStyle = .overCurrentContext
    nav.view.backgroundColor = UIColor.clear
    nav.interactivePopGestureRecognizer!.state = .began
    self.presentingViewController?.present(nav, animated: true, completion: nil)
  }

  override func interactiveDidFinish(vc: UIViewController) {
    guard let vc = vc as? StorageViewController else { return }

    vc.viewModel.coordinator.detach()
  }
}
