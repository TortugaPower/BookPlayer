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
    let vc = PlayerControlsViewController.instantiate(from: .Player)
    let viewModel = PlayerControlsViewModel(playerManager: self.playerManager)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    
    self.navigationController.navigationBar.prefersLargeTitles = false
    self.navigationController.viewControllers = [vc]
    self.navigationController.presentationController?.delegate = self
    
    if !UIAccessibility.isVoiceOverRunning,
       #available(iOS 15.0, *),
       let sheet = self.navigationController.sheetPresentationController {
      sheet.detents = [.medium()]
    }
    
    self.presentingViewController?.present(self.navigationController, animated: true, completion: nil)
  }
}
