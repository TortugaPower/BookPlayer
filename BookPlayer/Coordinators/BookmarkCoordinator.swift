//
//  BookmarkCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit

class BookmarkCoordinator: Coordinator {
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol

  init(navigationController: UINavigationController,
       playerManager: PlayerManagerProtocol,
       libraryService: LibraryServiceProtocol) {
    self.playerManager = playerManager
    self.libraryService = libraryService

    super.init(navigationController: navigationController,
               flowType: .modal)
  }

  override func start() {
    let vc = BookmarksViewController.instantiate(from: .Player)
    let viewModel = BookmarksViewModel(playerManager: self.playerManager,
                                       libraryService: self.libraryService)
    viewModel.coordinator = self
    vc.viewModel = viewModel

    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]
    nav.presentationController?.delegate = self
    self.presentingViewController?.present(nav, animated: true, completion: nil)
    self.presentingViewController = nav
  }

  func showExportController(currentItem: PlayableItem, bookmarks: [Bookmark]) {
    let provider = BookmarksActivityItemProvider(currentItem: currentItem, bookmarks: bookmarks)

    let shareController = UIActivityViewController(activityItems: [provider], applicationActivities: nil)

    self.presentingViewController?.present(shareController, animated: true, completion: nil)
  }
}
