//
//  FolderListCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class FolderListCoordinator: ItemListCoordinator {
  var folder: Folder

  init(
    navigationController: UINavigationController,
    library: Library,
    folder: Folder,
    playerManager: PlayerManager
  ) {
    self.folder = folder

    super.init(
      navigationController: navigationController,
      library: library,
      playerManager: playerManager
    )
  }

  override func start() {
    let vc = PlaylistViewController.instantiate(from: .Main)
    vc.coordinator = self
    vc.folder = self.folder
    self.navigationController.pushViewController(vc, animated: true)
  }
}
