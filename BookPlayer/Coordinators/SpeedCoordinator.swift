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
  let libraryService: LibraryServiceProtocol
  let playerManager: PlayerManagerProtocol

  init(libraryService: LibraryServiceProtocol,
       playerManager: PlayerManagerProtocol,
       navigationController: UINavigationController) {
    self.libraryService = libraryService
    self.playerManager = playerManager

    super.init(navigationController: navigationController, flowType: .modal)
  }

  override func start() {
      let vc = SpeedViewController.instantiate(from: .Player)
      let viewModel = SpeedViewModel(playerManager: self.playerManager, libraryService: self.libraryService)
      viewModel.coordinator = self
      vc.viewModel = viewModel
      
      let nav = AppNavigationController.instantiate(from: .Main)
      nav.viewControllers = [vc]
      nav.presentationController?.delegate = self
      nav.modalPresentationStyle = .overCurrentContext
      nav.view.backgroundColor = UIColor.clear
      self.presentingViewController?.present(nav, animated: true, completion: nil)
  }

  override func interactiveDidFinish(vc: UIViewController) {
    guard let vc = vc as? StorageViewController else { return }

    vc.viewModel.coordinator.detach()
  }
}
