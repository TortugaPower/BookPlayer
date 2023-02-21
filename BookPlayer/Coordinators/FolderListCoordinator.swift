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
  let folderRelativePath: String

  init(
    navigationController: UINavigationController,
    folderRelativePath: String,
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.folderRelativePath = folderRelativePath

    super.init(
      navigationController: navigationController,
      playerManager: playerManager,
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService
    )
  }

  override func start() {
    let vc = ItemListViewController.instantiate(from: .Main)
    let viewModel = ItemListViewModel(
      folderRelativePath: self.folderRelativePath,
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      playbackService: self.playbackService,
      syncService: self.syncService,
      themeAccent: ThemeManager.shared.currentTheme.linkColor
    )
    viewModel.onTransition = { [weak self] route in
      switch route {
      case .showFolder(let relativePath):
        self?.showFolder(relativePath)
      case .loadPlayer(let relativePath):
        self?.loadPlayer(relativePath)
      }
    }
    viewModel.coordinator = self
    vc.viewModel = viewModel
    presentingViewController = navigationController
    navigationController.pushViewController(vc, animated: true)

    documentPickerDelegate = vc
    syncList()
  }

  override func showOperationCompletedAlert(with items: [LibraryItem], availableFolders: [SimpleLibraryItem]) {
    let alert = UIAlertController(
      title: String.localizedStringWithFormat("import_alert_title".localized, items.count),
      message: nil,
      preferredStyle: .alert)

    alert.addAction(UIAlertAction(title: "current_playlist_title".localized, style: .default, handler: nil))

    alert.addAction(UIAlertAction(title: "library_title".localized, style: .default) { [weak self] _ in
      self?.onAction?(.insertIntoLibrary(items))
    })

    alert.addAction(UIAlertAction(title: "new_playlist_button".localized, style: .default) { [weak self] _ in
      var placeholder = "new_playlist_button".localized

      if let item = items.first {
        placeholder = item.title
      }

      self?.showCreateFolderAlert(placeholder: placeholder, with: items.map { $0.relativePath }, type: .folder)
    })

    let existingFolderAction = UIAlertAction(title: "existing_playlist_button".localized, style: .default) { _ in
      let vc = ItemSelectionViewController()
      vc.items = availableFolders

      vc.onItemSelected = { selectedFolder in
        self.onAction?(.importIntoFolder(selectedFolder, items: items, type: .folder))
      }

      let nav = AppNavigationController(rootViewController: vc)
      self.navigationController.present(nav, animated: true, completion: nil)
    }

    existingFolderAction.isEnabled = !availableFolders.isEmpty
    alert.addAction(existingFolderAction)

    self.navigationController.present(alert, animated: true, completion: nil)
  }

  override func syncList() {
    Task { [weak self] in
      try? await self?.syncService.fetchListContents(at: folderRelativePath, shouldSync: false)
    }
  }
}
