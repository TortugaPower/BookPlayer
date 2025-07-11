//
//  FolderListCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import UIKit

class FolderListCoordinator: ItemListCoordinator {
  let folderRelativePath: String

  init(
    flow: BPCoordinatorPresentationFlow,
    folderRelativePath: String,
    playerManager: PlayerManagerProtocol,
    singleFileDownloadService: SingleFileDownloadService,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol,
    importManager: ImportManager,
    listRefreshService: ListSyncRefreshService,
    jellyfinConnectionService: JellyfinConnectionService,
    hardcoverService: HardcoverServiceProtocol
  ) {
    self.folderRelativePath = folderRelativePath

    super.init(
      flow: flow,
      playerManager: playerManager,
      singleFileDownloadService: singleFileDownloadService,
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService, 
      importManager: importManager,
      listRefreshService: listRefreshService,
      jellyfinConnectionService: jellyfinConnectionService,
      hardcoverService: hardcoverService
    )
  }

  override func start() {
    let vc = ItemListViewController.instantiate(from: .Main)
    let viewModel = ItemListViewModel(
      folderRelativePath: self.folderRelativePath,
      playerManager: self.playerManager,
      singleFileDownloadService: self.singleFileDownloadService,
      libraryService: self.libraryService,
      playbackService: self.playbackService,
      syncService: self.syncService, 
      importManager: self.importManager, 
      listRefreshService: listRefreshService,
      hardcoverService: hardcoverService,
      themeAccent: ThemeManager.shared.currentTheme.linkColor
    )
    viewModel.onTransition = { route in
      switch route {
      case .showFolder(let relativePath):
        self.showFolder(relativePath)
      case .loadPlayer(let relativePath):
        self.loadPlayer(relativePath)
      case .showDocumentPicker:
        self.showDocumentPicker()
      case .showJellyfinDownloader:
        self.showJellyfinDownloader()
      case .showSearchList(let relativePath, let placeholderTitle):
        self.showSearchList(at: relativePath, placeholderTitle: placeholderTitle)
      case .showItemDetails(let item):
        self.showItemDetails(item)
      case .showExportController(let items):
        self.showExportController(for: items)
      case .showItemSelectionScreen(let availableItems, let selectionHandler):
        self.showItemSelectionScreen(availableItems: availableItems, selectionHandler: selectionHandler)
      case .showMiniPlayer(let flag):
        self.showMiniPlayer(flag: flag)
      case .listDidLoad:
        self.syncList()
      case .listDidAppear:
        break
      case .showQueuedTasks:
        self.showQueuedTasks()
      }
    }
    viewModel.coordinator = self
    vc.viewModel = viewModel
    flow.startPresentation(vc, animated: true)

    documentPickerDelegate = vc
  }

  override func syncList() {
    Task {
      guard
        await syncService.canSyncListContents(at: folderRelativePath, ignoreLastTimestamp: false)
      else { return }

      await listRefreshService.syncList(at: folderRelativePath, alertPresenter: self)
      await MainActor.run {
        self.reloadItemsWithPadding()
      }
    }
  }
}
