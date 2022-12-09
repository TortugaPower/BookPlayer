//
//  ItemListViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import MediaPlayer
import Themeable

class ItemListViewModel: BaseViewModel<ItemListCoordinator> {
  let folderRelativePath: String?
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  var offset = 0

  public private(set) var defaultArtwork: Data?
  public private(set) var itemsUpdates = PassthroughSubject<[SimpleLibraryItem], Never>()
  public private(set) var itemProgressUpdates = PassthroughSubject<IndexPath, Never>()
  public private(set) var items = [SimpleLibraryItem]()
  private var bookProgressSubscription: AnyCancellable?
  private var disposeBag = Set<AnyCancellable>()
  /// Cached path for containing folder of playing item in relation to this list path
  private var playingItemParentPath: String?

  public var maxItems: Int {
    return self.libraryService.getMaxItemsCount(at: self.folderRelativePath)
  }

  init(
    folderRelativePath: String?,
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    themeAccent: UIColor
  ) {
    self.folderRelativePath = folderRelativePath
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: themeAccent)?.pngData()
    super.init()

    self.bindBookObservers()
  }

  func getEmptyStateImageName() -> String {
    return self.coordinator is LibraryListCoordinator
    ? "emptyLibrary"
    : "emptyPlaylist"
  }

  func getNavigationTitle() -> String {
    guard let folderRelativePath = folderRelativePath else {
      return "library_title".localized
    }

    guard let item = self.libraryService.getItem(with: folderRelativePath) else {
      return ""
    }

    return item.title
  }

  func bindBookObservers() {
    self.playerManager.currentItemPublisher().sink { [weak self] currentItem in
      guard let self = self else { return }

      self.bookProgressSubscription?.cancel()

      defer {
        self.clearPlaybackState()
      }

      guard let currentItem = currentItem else {
        self.playingItemParentPath = nil
        return
      }

      self.playingItemParentPath = self.getPathForParentOfItem(currentItem: currentItem)

      self.bindItemProgressObserver(currentItem)
    }.store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .folderProgressUpdated)
      .sink { [weak self] notification in
        guard
          let playingItemParentPath = self?.playingItemParentPath,
          let relativePath = notification.userInfo?["relativePath"] as? String,
          playingItemParentPath == relativePath,
          let index = self?.items.firstIndex(where: { relativePath == $0.relativePath }),
          let progress = notification.userInfo?["progress"] as? Double
        else {
          return
        }

        self?.items[index].percentCompleted = progress

        let indexModified = IndexPath(row: index, section: BPSection.data.rawValue)
        self?.itemProgressUpdates.send(indexModified)
      }.store(in: &disposeBag)
  }

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

  func bindItemProgressObserver(_ item: PlayableItem) {
    self.bookProgressSubscription?.cancel()
    self.bookProgressSubscription = item.publisher(for: \.percentCompleted)
      .combineLatest(item.publisher(for: \.relativePath))
      .removeDuplicates(by: { $0.0 == $1.0 })
      .sink(receiveValue: { [weak self] (percentCompleted, relativePath) in
        /// Check if item is in this list, otherwise do not process progress update
        guard
          let self = self,
          item.parentFolder == self.folderRelativePath,
          let index = self.items.firstIndex(where: { relativePath == $0.relativePath })
        else { return }

        self.items[index].percentCompleted = percentCompleted

        let indexModified = IndexPath(row: index, section: BPSection.data.rawValue)
        self.itemProgressUpdates.send(indexModified)
      })
  }

  func clearPlaybackState() {
    self.itemsUpdates.send(self.items)
  }

  func loadInitialItems(pageSize: Int = 13) -> [SimpleLibraryItem] {
    guard
      let fetchedItems = self.libraryService.fetchContents(
        at: self.folderRelativePath,
        limit: pageSize,
        offset: 0
      )
    else {
      return []
    }

    self.offset = fetchedItems.count
    self.items = fetchedItems

    return fetchedItems
  }

  func loadNextItems(pageSize: Int = 13) {
    guard self.offset < self.maxItems else { return }

    guard
      let fetchedItems = self.libraryService.fetchContents(
        at: self.folderRelativePath,
        limit: pageSize,
        offset: self.offset
      ),
      !fetchedItems.isEmpty
    else {
      return
    }

    self.offset += fetchedItems.count

    self.items += fetchedItems
    self.itemsUpdates.send(self.items)
  }

  func loadAllItemsIfNeeded() {
    guard self.offset < self.maxItems else { return }

    guard
      let fetchedItems = self.libraryService.fetchContents(
        at: self.folderRelativePath,
        limit: self.maxItems,
        offset: 0
      ),
      !fetchedItems.isEmpty
    else {
      return
    }

    self.offset = fetchedItems.count
    self.items = fetchedItems
    self.itemsUpdates.send(self.items)
  }

  func getItem(of type: SimpleItemType, after currentIndex: Int) -> Int? {
    guard let (index, _) = (self.items.enumerated().first { (index, item) in
      guard index > currentIndex else { return false }

      return item.type == type
    }) else { return nil }

    return index
  }

  func getItem(of type: SimpleItemType, before currentIndex: Int) -> Int? {
    guard let (index, _) = (self.items.enumerated().reversed().first { (index, item) in
      guard index < currentIndex else { return false }

      return item.type == type
    }) else { return nil }

    return index
  }

  func playNextBook(in item: SimpleLibraryItem) {
    switch item.type {
    case .book, .bound:
      self.coordinator.loadPlayer(item.relativePath)
    case .folder:
      guard
        let currentItem = self.playerManager.currentItem,
        currentItem.relativePath.contains(item.relativePath)
      else {
        if let folder = self.libraryService.getItem(with: item.relativePath) as? Folder {
          self.coordinator.loadNextBook(in: folder)
        }
        return
      }

      self.coordinator.loadPlayer(currentItem.relativePath)
    }
  }

  func reloadItems(pageSizePadding: Int = 0) {
    let pageSize = self.items.count + pageSizePadding
    let loadedItems = self.loadInitialItems(pageSize: pageSize)
    self.itemsUpdates.send(loadedItems)
  }

  func getPlaybackState(for item: SimpleLibraryItem) -> PlaybackState {
    guard let currentItem = self.playerManager.currentItem else {
      return .stopped
    }

    if item.relativePath == currentItem.relativePath {
      return .playing
    }

    return item.relativePath == playingItemParentPath ? .playing : .stopped
  }

  func showItemContents(_ item: SimpleLibraryItem) {
    self.coordinator.showItemContents(item)
  }

  func importIntoFolder(_ folder: SimpleLibraryItem, items: [LibraryItem], type: SimpleItemType) {
    let fetchedItems = items.compactMap({ self.libraryService.getItem(with: $0.relativePath )})

    do {
      try self.libraryService.moveItems(fetchedItems, inside: folder.relativePath, moveFiles: true)
      try self.libraryService.updateFolder(at: folder.relativePath, type: type)

      libraryService.rebuildFolderDetails(folder.relativePath)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func createFolder(with title: String, items: [String]? = nil, type: SimpleItemType) {
    do {
      let folder = try self.libraryService.createFolder(with: title, inside: self.folderRelativePath)
      if let fetchedItems = items?.compactMap({ self.libraryService.getItem(with: $0 )}) {
        try self.libraryService.moveItems(fetchedItems, inside: folder.relativePath, moveFiles: true)
      }
      try self.libraryService.updateFolder(at: folder.relativePath, type: type)
      libraryService.rebuildFolderDetails(folder.relativePath)

      // stop playback if folder items contain that current item
      if let items = items,
         let currentRelativePath = self.playerManager.currentItem?.relativePath,
         items.contains(currentRelativePath) {
        self.playerManager.stop()
      }

    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding(padding: 1)
  }

  func updateFolders(_ folders: [SimpleLibraryItem], type: SimpleItemType) {
    do {
      try folders.forEach { folder in
        try self.libraryService.updateFolder(at: folder.relativePath, type: type)

        if let currentItem = self.playerManager.currentItem,
           currentItem.relativePath.contains(folder.relativePath) {
          self.playerManager.stop()
        }
      }
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleMoveIntoLibrary(items: [SimpleLibraryItem]) {
    let selectedItems = items.compactMap({ self.libraryService.getItem(with: $0.relativePath )})
    let parentFolder = items.first?.parentFolder

    do {
      try self.libraryService.moveItems(selectedItems, inside: nil, moveFiles: true)
      if let parentFolder {
        libraryService.rebuildFolderDetails(parentFolder)
      }
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding(padding: selectedItems.count)
  }

  func handleMoveIntoFolder(_ folder: SimpleLibraryItem, items: [SimpleLibraryItem]) {
    ArtworkService.removeCache(for: folder.relativePath)

    let fetchedItems = items.compactMap({ self.libraryService.getItem(with: $0.relativePath )})

    do {
      try self.libraryService.moveItems(fetchedItems, inside: folder.relativePath, moveFiles: true)
      self.libraryService.rebuildFolderDetails(folder.relativePath)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleDelete(items: [SimpleLibraryItem], mode: DeleteMode) {
    let selectedItems = items.compactMap({ self.libraryService.getItem(with: $0.relativePath )})
    let parentFolder = items.first?.parentFolder

    do {
      try self.libraryService.delete(selectedItems, mode: mode)
      if let parentFolder {
        libraryService.rebuildFolderDetails(parentFolder)
      }
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleOperationCompletion(_ files: [URL]) {
		print("handleOperationCompletion init")
    let library = self.libraryService.getLibrary()
    let processedItems = self.libraryService.insertItems(from: files, into: nil, library: library, processedItems: [])

    do {
      let shouldMoveFiles = self.folderRelativePath != nil

      try self.libraryService.moveItems(processedItems, inside: self.folderRelativePath, moveFiles: shouldMoveFiles)
      if let folderRelativePath = self.folderRelativePath {
        libraryService.rebuildFolderDetails(folderRelativePath)
      }
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
      return
    }
		print("handleOperationCompletion processedItems \(processedItems.count)")
    self.coordinator.reloadItemsWithPadding(padding: processedItems.count)

    var availableFolders = [SimpleLibraryItem]()

    if let existingItems = self.libraryService.fetchContents(
      at: self.folderRelativePath,
      limit: nil,
      offset: nil
    ) {
      let existingFolders = existingItems.filter({ $0.type == .folder })

      for folder in existingFolders {
        if processedItems.contains(where: { $0.relativePath == folder.relativePath }) { continue }

        availableFolders.append(folder)
      }
    }

    if processedItems.count > 1 {
      self.coordinator.showOperationCompletedAlert(with: processedItems, availableFolders: availableFolders)
    }
  }

  func handleInsertionIntoLibrary(_ items: [LibraryItem]) {
    do {
      try self.libraryService.moveItems(items, inside: nil, moveFiles: true)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }
		print("handleInsertionIntoLibrary items")
		print(items)
    self.coordinator.reloadItemsWithPadding(padding: items.count)
  }

  func reorder(item: SimpleLibraryItem, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {
    if let folderRelativePath = folderRelativePath {
      ArtworkService.removeCache(for: folderRelativePath)
    }

    self.libraryService.reorderItem(
      at: item.relativePath,
      inside: self.folderRelativePath,
      sourceIndexPath: sourceIndexPath,
      destinationIndexPath: destinationIndexPath
    )

    _ = self.loadInitialItems(pageSize: self.items.count)
  }

  func updateDefaultArtwork(for theme: SimpleTheme) {
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: theme.linkColor)?.pngData()
  }

  func showMiniPlayer(_ flag: Bool) {
    if let mainCoordinator = self.coordinator?.getMainCoordinator() {
      mainCoordinator.showMiniPlayer(flag)
    }
  }

  func showAddActions() {
    self.coordinator.showAddActions()
  }

  func notifyPendingFiles() {
    // Get reference of all the files located inside the Documents, Shared and Inbox folders
    let documentsURLs = ((try? FileManager.default.contentsOfDirectory(
      at: DataManager.getDocumentsFolderURL(),
      includingPropertiesForKeys: nil,
      options: .skipsSubdirectoryDescendants
    )) ?? [])
      .filter {
        $0.lastPathComponent != DataManager.processedFolderName
        && $0.lastPathComponent != DataManager.inboxFolderName
      }

    let sharedURLs = (try? FileManager.default.contentsOfDirectory(
      at: DataManager.getSharedFilesFolderURL(),
      includingPropertiesForKeys: nil,
      options: .skipsSubdirectoryDescendants
    )) ?? []

    let inboxURLs = (try? FileManager.default.contentsOfDirectory(
      at: DataManager.getInboxFolderURL(),
      includingPropertiesForKeys: nil,
      options: .skipsSubdirectoryDescendants
    )) ?? []

    let urls = documentsURLs + sharedURLs + inboxURLs

    guard !urls.isEmpty else { return }

    self.handleNewFiles(urls)
  }

  func handleNewFiles(_ urls: [URL]) {
    self.coordinator.getMainCoordinator()?.getLibraryCoordinator()?.processFiles(urls: urls)
  }

  private func getAvailableFolders(notIn items: [SimpleLibraryItem]) -> [SimpleLibraryItem] {
    var availableFolders = [SimpleLibraryItem]()

    guard
      let existingItems = libraryService.fetchContents(
        at: self.folderRelativePath,
        limit: nil,
        offset: nil
      )
    else { return [] }

    let existingFolders = existingItems.filter({ $0.type == .folder })

    for folder in existingFolders {
      if items.contains(where: { $0.relativePath == folder.relativePath }) { continue }

      availableFolders.append(folder)
    }

    return availableFolders
  }

  func showSortOptions() {
    self.coordinator.showSortOptions()
  }

  func showItemDetails(_ item: SimpleLibraryItem) {
    self.coordinator.showItemDetails(item)
  }

  func showMoveOptions(selectedItems: [SimpleLibraryItem]) {
    let availableFolders = getAvailableFolders(notIn: selectedItems)

    self.coordinator.showMoveOptions(selectedItems: selectedItems, availableFolders: availableFolders)
  }

  func showDeleteOptions(selectedItems: [SimpleLibraryItem]) {
    self.coordinator.showDeleteAlert(selectedItems: selectedItems)
  }

  func showMoreOptions(selectedItems: [SimpleLibraryItem]) {
    let availableFolders = getAvailableFolders(notIn: selectedItems)

    self.coordinator.showMoreOptionsAlert(selectedItems: selectedItems, availableFolders: availableFolders)
  }

  func showSearchList() {
    self.coordinator.showSearchList(at: folderRelativePath, placeholderTitle: getNavigationTitle())
  }

  func handleSort(by option: SortType) {
    self.libraryService.sortContents(at: folderRelativePath, by: option)
    self.reloadItems()
  }

  func handleResetPlaybackPosition(for items: [SimpleLibraryItem]) {
    items.forEach({ self.libraryService.jumpToStart(relativePath: $0.relativePath) })

    self.coordinator.reloadItemsWithPadding()
  }

  func handleMarkAsFinished(for items: [SimpleLibraryItem], flag: Bool) {
    let parentFolder = items.first?.parentFolder

    items.forEach { [unowned self] in
      self.libraryService.markAsFinished(flag: flag, relativePath: $0.relativePath)
    }

    if let parentFolder {
      self.libraryService.rebuildFolderDetails(parentFolder)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleDownload(_ url: URL) {
    NetworkService.shared.download(from: url) { [weak self] response in
      NotificationCenter.default.post(name: .downloadEnd, object: self)

      if response.error != nil,
         let error = response.error {
        self?.coordinator.showAlert("network_error_title".localized, message: error.localizedDescription)
      }

      if let response = response.response, response.statusCode >= 300 {
        self?.coordinator.showAlert("network_error_title".localized, message: "Code \(response.statusCode)")
      }
    }
  }

  func importData(from item: ImportableItem) {
    let filename = item.suggestedName ?? "\(Date().timeIntervalSince1970).\(item.fileExtension)"

    let destinationURL = DataManager.getDocumentsFolderURL()
      .appendingPathComponent(filename)

    do {
      try item.data.write(to: destinationURL)
    } catch {
      print("Fail to move dropped file to the Documents directory: \(error.localizedDescription)")
    }
  }
}
