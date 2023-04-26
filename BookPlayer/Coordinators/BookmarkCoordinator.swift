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
  let syncService: SyncServiceProtocol

  init(
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol,
    presentingViewController: UIViewController?
  ) {
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
    super.init(
      navigationController: AppNavigationController.instantiate(from: .Player),
      flowType: .modal
    )

    self.presentingViewController = presentingViewController
  }

  override func start() {
    let vc = BookmarksViewController.instantiate(from: .Player)
    let viewModel = BookmarksViewModel(
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    viewModel.coordinator = self
    vc.viewModel = viewModel

    self.navigationController.viewControllers = [vc]
    self.navigationController.presentationController?.delegate = self
    self.presentingViewController?.present(self.navigationController, animated: true, completion: nil)
  }

  func showExportController(currentItem: PlayableItem, bookmarks: [SimpleBookmark]) {
    let provider = BookmarksActivityItemProvider(currentItem: currentItem, bookmarks: bookmarks)

    let shareController = UIActivityViewController(activityItems: [provider], applicationActivities: nil)

    self.presentingViewController?.present(shareController, animated: true, completion: nil)
  }
}
