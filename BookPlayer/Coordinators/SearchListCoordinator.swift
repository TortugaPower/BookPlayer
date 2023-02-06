//
//  SearchListCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 1/11/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

class SearchListCoordinator: Coordinator {
  var folderRelativePath: String?
  let placeholderTitle: String
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let syncService: SyncServiceProtocol

  init(
    navigationController: UINavigationController,
    placeholderTitle: String,
    folderRelativePath: String?,
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.folderRelativePath = folderRelativePath
    self.placeholderTitle = placeholderTitle
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.syncService = syncService

    super.init(
      navigationController: navigationController,
      flowType: .push
    )
  }

  override func start() {
    let viewModel = SearchListViewModel(
      folderRelativePath: folderRelativePath,
      placeholderTitle: placeholderTitle,
      libraryService: libraryService,
      playerManager: playerManager,
      themeAccent: ThemeManager.shared.currentTheme.linkColor
    )
    viewModel.onTransition = { route in
      switch route {
      case .itemSelected(let item):
        self.showItemContents(item)
      }
    }
    let vc = SearchListViewController(viewModel: viewModel)

    self.navigationController.pushViewController(vc, animated: true)
  }

  func showItemContents(_ item: SimpleLibraryItem) {
    switch item.type {
    case .folder:
      self.showFolder(item.relativePath)
    case .book, .bound:
      self.loadPlayer(item.relativePath)
    }
  }

  func showFolder(_ relativePath: String) {
    let child = FolderListCoordinator(
      navigationController: self.navigationController,
      folderRelativePath: relativePath,
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      playbackService: self.playbackService,
      syncService: syncService
    )
    self.childCoordinators.append(child)
    child.parentCoordinator = self
    child.start()
  }

  func loadPlayer(_ relativePath: String) {
    AppDelegate.shared?.loadPlayer(
      relativePath,
      autoplay: true,
      showPlayer: { [weak self] in
        self?.showPlayer()
      },
      alertPresenter: self
    )
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      presentingViewController: self.navigationController
    )
    playerCoordinator.parentCoordinator = self
    self.childCoordinators.append(playerCoordinator)
    playerCoordinator.start()
  }
}
