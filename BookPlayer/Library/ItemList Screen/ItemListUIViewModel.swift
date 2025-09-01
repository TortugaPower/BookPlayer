//
//  ItemListUIViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import MediaPlayer
import Themeable

class ItemListUIViewModel {
  /// Available routes for this screen
  enum Routes {
    case showFolder(relativePath: String)
    case loadPlayer(relativePath: String)
    case showDocumentPicker
    case showJellyfinDownloader
    case showSearchList(relativePath: String?, placeholderTitle: String)
    case showItemDetails(item: SimpleLibraryItem)
    case showExportController(items: [SimpleLibraryItem])
    case showItemSelectionScreen(
      availableItems: [SimpleLibraryItem],
      selectionHandler: (SimpleLibraryItem) -> Void
    )
    case listDidLoad
    case listDidAppear
    case showQueuedTasks
  }

  enum Events {
    case newData
    case resetEditMode
    case reloadIndex(_ indexPath: IndexPath)
    case downloadState(_ state: DownloadState, indexPath: IndexPath)
    case showAlert(content: BPAlertContent)
    case showLoader(flag: Bool)
    case showProcessingView(Bool, title: String?, subtitle: String?)
  }

  let folderRelativePath: String?
  let playerManager: PlayerManagerProtocol
  let singleFileDownloadService: SingleFileDownloadService
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  private let listRefreshService: ListSyncRefreshService
  let syncService: SyncServiceProtocol
  private let importManager: ImportManager
  private let hardcoverService: HardcoverServiceProtocol
  var offset = 0

  public private(set) var defaultArtwork: Data?
  public private(set) var items = [SimpleLibraryItem]()

  var eventsPublisher = InterfaceUpdater<ItemListUIViewModel.Events>()

  private var bookProgressSubscription: AnyCancellable?
  /// Callback to handle actions on this screen
  public var onTransition: BPTransition<Routes>?

  private var disposeBag = Set<AnyCancellable>()
  /// Cached path for containing folder of playing item in relation to this list path
  private var playingItemParentPath: String?

  public var maxItems: Int {
    return self.libraryService.getMaxItemsCount(at: self.folderRelativePath)
  }

  /// Initializer
  init(
    folderRelativePath: String?,
    playerManager: PlayerManagerProtocol,
    singleFileDownloadService: SingleFileDownloadService,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol,
    importManager: ImportManager,
    listRefreshService: ListSyncRefreshService,
    hardcoverService: HardcoverServiceProtocol,
    themeAccent: UIColor
  ) {
    self.folderRelativePath = folderRelativePath
    self.playerManager = playerManager
    self.singleFileDownloadService = singleFileDownloadService
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.syncService = syncService
    self.importManager = importManager
    self.listRefreshService = listRefreshService
    self.hardcoverService = hardcoverService
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: themeAccent)?.pngData()
  }

//  private func playNextBook(in item: SimpleLibraryItem) {
//    guard item.type == .folder else { return }
//
//    /// If the player already is playing a subset of this folder, let the player handle playback
//    if let currentItem = self.playerManager.currentItem,
//       currentItem.relativePath.contains(item.relativePath) {
//      self.playerManager.play()
//    } else if let nextPlayableItem = try? self.playbackService.getFirstPlayableItem(
//      in: item,
//      isUnfinished: true
//    ),
//              let nextItem = libraryService.getSimpleItem(with: nextPlayableItem.relativePath) {
//      showItemContents(nextItem)
//    }
//  }

//  func handleArtworkTap(for item: SimpleLibraryItem) {
//    switch getDownloadState(for: item) {
//    case .notDownloaded:
//      startDownload(of: item)
//    case .downloading:
//      cancelDownload(of: item)
//    case .downloaded:
//      switch item.type {
//      case .folder:
//        playNextBook(in: item)
//      case .bound, .book:
//        onTransition?(.loadPlayer(relativePath: item.relativePath))
//      }
//    }
//  }
}
