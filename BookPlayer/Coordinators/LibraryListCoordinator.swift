//
//  LibraryListCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class LibraryListCoordinator: ItemListCoordinator {
  let miniPlayerOffset: CGFloat

  init(
    navigationController: UINavigationController,
    library: Library,
    miniPlayerOffset: CGFloat,
    playerManager: PlayerManager
  ) {
    self.miniPlayerOffset = miniPlayerOffset

    super.init(
      navigationController: navigationController,
      library: library,
      playerManager: playerManager
    )
  }

  override func start() {
    let vc = LibraryViewController.instantiate(from: .Main)
    vc.coordinator = self
    self.navigationController.pushViewController(vc, animated: false)
  }
}
