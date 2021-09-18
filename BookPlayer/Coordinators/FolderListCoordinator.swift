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
    playerManager: PlayerManager,
    miniPlayerOffset: CGFloat
  ) {
    self.folder = folder

    super.init(
      navigationController: navigationController,
      library: library,
      miniPlayerOffset: miniPlayerOffset,
      playerManager: playerManager
    )
  }

  override func start() {
    let vc = FolderListViewController.instantiate(from: .Main)
    let viewModel = FolderListViewModel(folder: self.folder,
                                        library: self.library,
                                        player: self.playerManager,
                                        theme: ThemeManager.shared.currentTheme)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    self.navigationController.pushViewController(vc, animated: true)
  }
}
