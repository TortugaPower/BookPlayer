//
//  SearchListViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/11/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class SearchListViewModel: BaseViewModel<Coordinator> {
  /// Available routes for this screen
  enum Routes {
    case showFolder(relativePath: String)
    case loadPlayer(relativePath: String)
  }

  /// Search only the folder if entered search via a subfolder
  let folderRelativePath: String?
  /// Title for the placeholder of space we're searching (e.g. Library, or folder name)
  let placeholderTitle: String
  /// Library service used to search the items
  let libraryService: LibraryServiceProtocol
  /// Sync service
  let syncService: SyncServiceProtocol

  let playerManager: PlayerManagerProtocol
  /// Default artwork to use for items without artwork
  public private(set) var defaultArtwork: Data?
  /// Array of items found
  public private(set) var items = CurrentValueSubject<[SimpleLibraryItem], Never>([])
  /// Scheduled job to avoid multiple calls on each keystroke
  private var searchJob: DispatchWorkItem?
  /// Search scopes available
  let searchScopes: [SimpleItemType] = [.book, .folder]
  /// Stored offset for the next page of results
  var resultsOffset = 0
  /// Size of results
  var pageSize = 13
  /// Cached path for containing folder of playing item in relation to this list path
  private var playingItemParentPath: String?
  /// Callback to handle actions on this screen
  public var onTransition: Transition<Routes>?
  private var disposeBag = Set<AnyCancellable>()

  /// Initializer
  init(
    folderRelativePath: String?,
    placeholderTitle: String,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol,
    playerManager: PlayerManagerProtocol,
    themeAccent: UIColor
  ) {
    self.folderRelativePath = folderRelativePath
    self.placeholderTitle = placeholderTitle
    self.libraryService = libraryService
    self.syncService = syncService
    self.playerManager = playerManager
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: themeAccent)?.pngData()
    super.init()

    self.bindPlayingItemObserver()
  }

  /// Observe when a new item is loaded into the player
  func bindPlayingItemObserver() {
    self.playerManager.currentItemPublisher()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] currentItem in
      guard let self = self else { return }

      defer {
        self.clearPlaybackState()
      }

      guard let currentItem = currentItem else {
        self.playingItemParentPath = nil
        return
      }

      self.playingItemParentPath = self.getPathForParentOfItem(currentItem: currentItem)
    }.store(in: &disposeBag)
  }

  /// Trigger a data reload
  func clearPlaybackState() {
    items.value = items.value
  }

  /// Used to properly tint folders that contain the currently playing item
  func getPathForParentOfItem(currentItem: PlayableItem) -> String? {
    let parentFolders: [String] = currentItem.relativePath.allRanges(of: "/")
      .map { String(currentItem.relativePath.prefix(upTo: $0.lowerBound)) }
      .reversed()

    guard let folderRelativePath = self.folderRelativePath else {
      return parentFolders.last
    }

    guard let index = parentFolders.firstIndex(of: folderRelativePath) else {
      return nil
    }

    let elementIndex = index - 1

    guard elementIndex >= 0 else {
      return nil
    }

    return parentFolders[elementIndex]
  }

  /// Get search scopes as String
  func getSearchScopes() -> [String] {
    return searchScopes.map { item in
      switch item {
      case .book, .bound:
        return "books_title".localized
      case .folder:
        return "folders_title".localized
      }
    }
  }

  /// Reset offset and loaded items and queue next page
  func filterItems(query: String?, scopeIndex: Int) {
    resultsOffset = 0
    items.value = []

    loadNextItems(query: query, scopeIndex: scopeIndex)
  }

  /// Execute search job after a delay
  func scheduleSearchJob(query: String?, scopeIndex: Int) {
    searchJob?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      guard let self = self else { return }

      self.filterItems(query: query, scopeIndex: scopeIndex)
    }
    searchJob = workItem

    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500), execute: workItem)
  }

  /// Load next page items with same query and selected scope
  func loadNextItems(query: String?, scopeIndex: Int) {
    Task { @MainActor in
      guard
        let fetchedItems = await libraryService.filterContents(
          at: folderRelativePath,
          query: query,
          scope: searchScopes[scopeIndex],
          limit: pageSize,
          offset: resultsOffset
        ),
        !fetchedItems.isEmpty
      else {
        return
      }

      resultsOffset += fetchedItems.count
      items.value += fetchedItems
    }
  }

  /// Pass callback with item selected
  func handleItemSelection(at index: Int) {
    let item = self.items.value[index]

    switch item.type {
    case .folder:
      onTransition?(.showFolder(relativePath: item.relativePath))
    case .book, .bound:
      onTransition?(.loadPlayer(relativePath: item.relativePath))
    }
  }

  /// Update default artwork after a new theme is presented
  func updateDefaultArtwork(for theme: SimpleTheme) {
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: theme.linkColor)?.pngData()
  }
  /// Return the playback state for the given item
  func getPlaybackState(for item: SimpleLibraryItem) -> PlaybackState {
    guard let currentItem = self.playerManager.currentItem else {
      return .stopped
    }

    if item.relativePath == currentItem.relativePath {
      return .playing
    }

    return item.relativePath == playingItemParentPath ? .playing : .stopped
  }
  /// Get download state of an item
  func getDownloadState(for item: SimpleLibraryItem) -> DownloadState {
    /// Only process if subscription is active
    guard syncService.isActive else { return .downloaded }

    let fileURL = item.fileURL

    if item.type == .bound,
       let enumerator = FileManager.default.enumerator(
         at: fileURL,
         includingPropertiesForKeys: nil,
         options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
       ),
       enumerator.nextObject() == nil {
      return .notDownloaded
    }

    if FileManager.default.fileExists(atPath: fileURL.path) {
      return .downloaded
    }

    return .notDownloaded
  }
}
