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
  let miniPlayerOffset: CGFloat
  let playerManager: PlayerManager
  let library: Library

  init(
    navigationController: UINavigationController,
    library: Library,
    miniPlayerOffset: CGFloat,
    playerManager: PlayerManager
  ) {
    self.library = library
    self.miniPlayerOffset = miniPlayerOffset
    self.playerManager = playerManager

    super.init(navigationController: navigationController)
  }

  override func start() {
    fatalError("ItemListCoordinator is an abstract class, override this function in the subclass")
  }

  func showItemContents(_ item: LibraryItem) {
    switch item {
    case let folder as Folder:
      self.showFolder(folder)
    case let book as Book:
      self.loadPlayer(book)
    default:
      break
    }
  }

  func showFolder(_ folder: Folder) {
    let child = FolderListCoordinator(navigationController: self.navigationController,
                                      library: self.library,
                                      folder: folder,
                                      playerManager: self.playerManager,
                                      miniPlayerOffset: self.miniPlayerOffset)
    self.childCoordinators.append(child)
    child.parentCoordinator = self.parentCoordinator
    child.start()
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      navigationController: self.navigationController,
      playerManager: self.playerManager
    )
    playerCoordinator.parentCoordinator = self
    self.childCoordinators.append(playerCoordinator)
    playerCoordinator.start()
  }

  func loadPlayer(_ book: Book) {
    guard DataManager.exists(book) else {
      self.navigationController.showAlert("file_missing_title".localized, message: "\("file_missing_description".localized)\n\(book.originalFileName ?? "")")
      return
    }

    self.showPlayer()

    // Only load if loaded book is a different one
    guard book.relativePath != playerManager.currentBook?.relativePath else { return }

    self.playerManager.load(book) { [weak self] loaded in
      guard loaded else { return }

      self?.playerManager.playPause()
    }
  }

  func loadLastBook(_ book: Book) {
    self.playerManager.load(book) { [weak self] loaded in
      guard loaded else { return }

      if UserDefaults.standard.bool(forKey: Constants.UserActivityPlayback) {
        UserDefaults.standard.removeObject(forKey: Constants.UserActivityPlayback)
        self?.playerManager.play()
      }

      if UserDefaults.standard.bool(forKey: Constants.UserDefaults.showPlayer.rawValue) {
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.showPlayer.rawValue)
        self?.showPlayer()
      }
    }
  }

  func showImport() {
    let child = ImportCoordinator(navigationController: self.navigationController)
    self.childCoordinators.append(child)
    child.parentCoordinator = self
    child.start()
  }
}
