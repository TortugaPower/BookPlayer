//
//  BookmarkCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import UIKit
import BookPlayerKit

class BookmarkCoordinator: Coordinator {
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol
  let flow: BPCoordinatorPresentationFlow

  init(
    flow: BPCoordinatorPresentationFlow,
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.flow = flow
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
  }

  func start() {
    let vc = BookmarksViewController.instantiate(from: .Player)
    let viewModel = BookmarksViewModel(
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    viewModel.coordinator = self
    vc.viewModel = viewModel

    viewModel.onTransition = { route in
      switch route {
      case .export(let bookmarks, let item):
        self.showExportController(currentItem: item, bookmarks: bookmarks)
      }
    }

    flow.startPresentation(vc, animated: true)
  }

  func showExportController(currentItem: PlayableItem, bookmarks: [SimpleBookmark]) {
    let provider = BookmarksActivityItemProvider(currentItem: currentItem, bookmarks: bookmarks)

    let shareController = UIActivityViewController(activityItems: [provider], applicationActivities: nil)

    if let popoverPresentationController = shareController.popoverPresentationController {
      popoverPresentationController.barButtonItem = flow.navigationController.topViewController?.navigationItem.rightBarButtonItem!
    }

    flow.navigationController.present(shareController, animated: true, completion: nil)
  }
}
