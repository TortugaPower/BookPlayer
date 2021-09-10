//
//  ItemListCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class ItemListCoordinator: Coordinator {
  var childCoordinators = [Coordinator]()
  var navigationController: UINavigationController
  weak var parentCoordinator: MainCoordinator?

  let playerManager: PlayerManager
  let library: Library

  init(navigationController: UINavigationController,
       library: Library,
       playerManager: PlayerManager) {
    self.navigationController = navigationController
    self.library = library
    self.playerManager = playerManager
  }

  func start() {
    fatalError("derp")
  }

  func showItemContents(_ item: LibraryItem) {
    switch item {
    case let folder as Folder:
      self.showFolder(folder)
    case let book as Book:
      self.showPlayer(book)
    default:
      break
    }
  }

  func showFolder(_ folder: Folder) {
    let child = FolderListCoordinator(navigationController: self.navigationController,
                                      library: self.library,
                                      folder: folder,
                                      playerManager: self.playerManager)
    self.parentCoordinator?.childCoordinators.append(child)
    child.parentCoordinator = self.parentCoordinator
    child.start()
  }

  func showPlayer(_ book: Book) {
    guard DataManager.exists(book) else {
      self.navigationController.showAlert("file_missing_title".localized, message: "\("file_missing_description".localized)\n\(book.originalFileName ?? "")")
      return
    }

    let playerCoordinator = PlayerCoordinator(
      navigationController: self.navigationController,
      playerManager: self.playerManager
    )
    playerCoordinator.parentCoordinator = self.parentCoordinator
    self.parentCoordinator?.childCoordinators.append(playerCoordinator)
    playerCoordinator.start()

    // Only load if loaded book is a different one
    guard book.relativePath != playerManager.currentBook?.relativePath else { return }

    self.playerManager.load(book) { [weak self] loaded in
      guard loaded else { return }

      self?.playerManager.playPause()
    }
  }
}
