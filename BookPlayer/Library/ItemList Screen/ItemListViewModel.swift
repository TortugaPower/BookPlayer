//
//  FolderListViewModel.swift
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

class FolderListViewModel: BaseViewModel<ItemListCoordinator> {
  let folder: Folder?
  let library: Library
  let player: PlayerManager
  let dataManager: DataManager
  var offset = 0

  public private(set) var defaultArtwork: Data?
  private var themeAccent: UIColor
  public private(set) var itemsUpdates = PassthroughSubject<[SimpleLibraryItem], Never>()
  public private(set) var itemProgressUpdates = PassthroughSubject<IndexPath, Never>()
  public private(set) var items = [SimpleLibraryItem]()
  private var bookSubscription: AnyCancellable?
  private var bookProgressSubscription: AnyCancellable?
  private var containingFolder: Folder?

  public var maxItems: Int {
    return self.folder?.items?.count ?? self.library.items?.count ?? 0
  }

  init(folder: Folder?,
       library: Library,
       player: PlayerManager,
       dataManager: DataManager,
       themeAccent: UIColor) {
    self.folder = folder
    self.library = library
    self.player = player
    self.dataManager = dataManager
    self.themeAccent = themeAccent
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: themeAccent)?.pngData()
    super.init()

    self.bindBookObserver()
  }

  func getEmptyStateImageName() -> String {
    return self.coordinator is LibraryListCoordinator
    ? "emptyLibrary"
    : "emptyPlaylist"
  }

  func getNavigationTitle() -> String {
    return self.folder?.title ?? "library_title".localized
  }

  func bindBookObserver() {
    self.bookSubscription = self.player.$currentBook.sink { [weak self] book in
      guard let self = self else { return }

      self.bookProgressSubscription?.cancel()
      self.containingFolder = nil

      guard let book = book else {
        self.clearPlaybackState()
        return
      }

      // Get folder reference for progress calculation
      if let item = self.items.first(where: { book.relativePath.contains($0.relativePath) && $0.type == .folder }) {
        self.containingFolder = book.getFolder(matching: item.relativePath)
      }

      self.bindBookProgressObserver(book)
    }
  }

  func bindBookProgressObserver(_ book: Book) {
    self.bookProgressSubscription?.cancel()

    self.bookProgressSubscription = book.publisher(for: \.percentCompleted)
      .combineLatest(book.publisher(for: \.relativePath))
      .removeDuplicates(by: { $0.0 == $1.0 })
      .sink(receiveValue: { [weak self] (percentCompleted, relativePath) in
        guard let self = self,
              let relativePath = relativePath,
              let index = self.items.firstIndex(where: { relativePath.contains($0.relativePath) }) else { return }

        let currentItem = self.items[index]

        var progress: Double?

        switch currentItem.type {
        case .book:
          progress = percentCompleted / 100
        case .folder:
          progress = self.containingFolder?.progressPercentage
        }

        let updatedItem = SimpleLibraryItem(from: currentItem, progress: progress, playbackState: .playing)

        self.items[index] = updatedItem

        let indexModified = IndexPath(row: index, section: Section.data.rawValue)
        self.itemProgressUpdates.send(indexModified)
      })
  }

  func clearPlaybackState() {
    self.items = self.items.map({ SimpleLibraryItem(from: $0, playbackState: .stopped) })
    self.itemsUpdates.send(self.items)
  }

  func loadInitialItems(pageSize: Int = 13) -> [SimpleLibraryItem] {
    guard let fetchedItems = self.dataManager.fetchContents(at: self.folder?.relativePath,
                                                            limit: pageSize,
                                                            offset: 0) else {
      return []
    }

    let displayItems = fetchedItems.map({ SimpleLibraryItem(
                                          from: $0,
                                          themeAccent: self.themeAccent,
                                          playbackState: self.getPlaybackState(for: $0)) })
    self.offset = displayItems.count
    self.items = displayItems

    return displayItems
  }

  func loadNextItems(pageSize: Int = 13) {
    guard self.offset < self.maxItems else { return }

    guard let fetchedItems = self.dataManager.fetchContents(at: self.folder?.relativePath,
                                                            limit: pageSize,
                                                            offset: self.offset),
          !fetchedItems.isEmpty else {
      return
    }

    let displayItems = fetchedItems.map({ SimpleLibraryItem(
                                          from: $0,
                                          themeAccent: self.themeAccent,
                                          playbackState: self.getPlaybackState(for: $0)) })
    self.offset += displayItems.count

    self.items += displayItems
    self.itemsUpdates.send(self.items)
  }

  func loadAllItemsIfNeeded() {
    guard self.offset < self.maxItems else { return }

    guard let fetchedItems = self.dataManager.fetchContents(at: self.folder?.relativePath,
                                                            limit: self.maxItems,
                                                            offset: 0),
          !fetchedItems.isEmpty else {
      return
    }

    let displayItems = fetchedItems.map({ SimpleLibraryItem(
                                          from: $0,
                                          themeAccent: self.themeAccent,
                                          playbackState: self.getPlaybackState(for: $0)) })
    self.offset = displayItems.count

    self.items = displayItems
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

  func playNextBook(after item: SimpleLibraryItem) {
    guard let libraryItem = self.dataManager.getItem(with: item.relativePath) else {
      return
    }

    var bookToPlay: Book?

    defer {
      if let book = bookToPlay {
        self.coordinator.loadPlayer(book)
      }
    }

    guard let folder = libraryItem as? Folder else {
      bookToPlay = libraryItem.getBookToPlay()
      return
    }

    // Special treatment for folders
    guard
      let bookPlaying = self.player.currentBook,
      let currentFolder = bookPlaying.folder,
      currentFolder == folder else {
        // restart the selected folder if current playing book has no relation to it
        if libraryItem.isFinished {
          self.dataManager.jumpToStart(libraryItem)
        }

        bookToPlay = libraryItem.getBookToPlay()
        return
      }

    // override next book with the one already playing
    bookToPlay = bookPlaying
  }

  func reloadItems(pageSizePadding: Int = 0) {
    let pageSize = self.items.count + pageSizePadding
    let loadedItems = self.loadInitialItems(pageSize: pageSize)
    self.itemsUpdates.send(loadedItems)
  }

  func checkSystemModeTheme() {
    ThemeManager.shared.checkSystemMode()
  }

  func getPlaybackState(for item: LibraryItem) -> PlaybackState {
    guard let book = self.player.currentBook else {
      return .stopped
    }

    return book.relativePath.contains(item.relativePath) ? .playing : .stopped
  }

  func showItemContents(_ item: SimpleLibraryItem) {
    guard let libraryItem = self.dataManager.getItem(with: item.relativePath) else {
      return
    }

    self.coordinator.showItemContents(libraryItem)
  }

  func importIntoNewFolder(with title: String, items: [LibraryItem]? = nil) {
    do {
      let folder = try self.dataManager.createFolder(with: title, in: self.folder, library: self.library)
      if let items = items {
        try self.dataManager.moveItems(items, into: folder)
      }
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding(padding: 1)
  }

  func importIntoFolder(_ folder: SimpleLibraryItem, items: [LibraryItem]) {
    guard let storedFolder = self.dataManager.getItem(with: folder.relativePath) as? Folder else { return }

    let fetchedItems = items.compactMap({ self.dataManager.getItem(with: $0.relativePath )})

    do {
      try self.dataManager.moveItems(fetchedItems, into: storedFolder)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func createFolder(with title: String, items: [SimpleLibraryItem]? = nil) {
    do {
      let folder = try self.dataManager.createFolder(with: title, in: self.folder, library: self.library)
      if let fetchedItems = items?.compactMap({ self.dataManager.getItem(with: $0.relativePath )}) {
        try self.dataManager.moveItems(fetchedItems, into: folder)
      }
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding(padding: 1)
  }

  func handleMoveIntoLibrary(items: [SimpleLibraryItem]) {
    let selectedItems = items.compactMap({ self.dataManager.getItem(with: $0.relativePath )})

    do {
      try self.dataManager.moveItems(selectedItems, into: self.library)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding(padding: selectedItems.count)
  }

  func handleMoveIntoFolder(_ folder: SimpleLibraryItem, items: [SimpleLibraryItem]) {
    ArtworkService.removeCache(for: folder.relativePath)

    guard let storedFolder = self.dataManager.getItem(with: folder.relativePath) as? Folder else { return }

    let fetchedItems = items.compactMap({ self.dataManager.getItem(with: $0.relativePath )})

    do {
      try self.dataManager.moveItems(fetchedItems, into: storedFolder)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleDelete(items: [SimpleLibraryItem], mode: DeleteMode) {
    let selectedItems = items.compactMap({ self.dataManager.getItem(with: $0.relativePath )})

    do {
      try self.dataManager.delete(selectedItems, library: self.library, mode: mode)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleOperationCompletion(_ files: [URL]) {
    let processedItems = self.dataManager.insertItems(from: files, into: nil, library: self.library)

    do {
      if let folder = self.folder {
        try self.dataManager.moveItems(processedItems, into: folder)
      } else {
        try self.dataManager.moveItems(processedItems, into: self.library, moveFiles: false)
      }

    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
      return
    }

    self.coordinator.reloadItemsWithPadding(padding: processedItems.count)

    var availableFolders = [SimpleLibraryItem]()

    if let existingFolders = self.dataManager.fetchFolders(in: self.folder, or: self.library) {
      for folder in existingFolders {
        if processedItems.contains(where: { $0.relativePath == folder.relativePath }) { continue }

        availableFolders.append(SimpleLibraryItem(from: folder, themeAccent: self.themeAccent))
      }
    }

    if processedItems.count > 1 {
      self.coordinator.showOperationCompletedAlert(with: processedItems, availableFolders: availableFolders)
    }
  }

  func handleInsertionIntoLibrary(_ items: [LibraryItem]) {
    do {
      try self.dataManager.moveItems(items, into: self.library)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding(padding: items.count)
  }

  func reorder(item: SimpleLibraryItem, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {
    guard let storedItem = self.dataManager.getItem(with: item.relativePath) else { return }

    if let folder = self.folder {
      ArtworkService.removeCache(for: folder.relativePath)
      folder.removeFromItems(at: sourceIndexPath.row)
      folder.insertIntoItems(storedItem, at: destinationIndexPath.row)
      folder.rebuildOrderRank()
    } else {
      self.library.removeFromItems(at: sourceIndexPath.row)
      self.library.insertIntoItems(storedItem, at: destinationIndexPath.row)
      self.library.rebuildOrderRank()
    }

    self.dataManager.saveContext()

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

  func showSettings() {
    self.coordinator.showSettings()
  }

  func showAddActions() {
    self.coordinator.showAddActions()
  }

  func notifyPendingFiles() {
    let documentsFolder = DataManager.getDocumentsFolderURL()

    // Get reference of all the files located inside the folder
    guard let urls = DataManager.getFiles(from: documentsFolder) else {
      return
    }

    self.handleNewFiles(urls)
  }

  func handleNewFiles(_ urls: [URL]) {
    self.coordinator.processFiles(urls: urls)
  }

  func showSortOptions() {
    self.coordinator.showSortOptions()
  }

  func showMoveOptions(selectedItems: [SimpleLibraryItem]) {
    var availableFolders = [SimpleLibraryItem]()

    if let existingFolders = self.dataManager.fetchFolders(in: self.folder, or: self.library) {
      for folder in existingFolders {
        if selectedItems.contains(where: { $0.relativePath == folder.relativePath }) { continue }

        availableFolders.append(SimpleLibraryItem(from: folder, themeAccent: self.themeAccent))
      }
    }

    self.coordinator.showMoveOptions(selectedItems: selectedItems, availableFolders: availableFolders)
  }

  func showDeleteOptions(selectedItems: [SimpleLibraryItem]) {
    self.coordinator.showDeleteAlert(selectedItems: selectedItems)
  }

  func showMoreOptions(selectedItems: [SimpleLibraryItem]) {
    var availableFolders = [SimpleLibraryItem]()

    if let existingFolders = self.dataManager.fetchFolders(in: self.folder, or: self.library) {
      for folder in existingFolders {
        if selectedItems.contains(where: { $0.relativePath == folder.relativePath }) { continue }

        availableFolders.append(SimpleLibraryItem(from: folder, themeAccent: self.themeAccent))
      }
    }

    self.coordinator.showMoreOptionsAlert(selectedItems: selectedItems, availableFolders: availableFolders)
  }

  func handleSort(by option: PlayListSortOrder) {
    let itemsToSortOptional: NSOrderedSet?

    if let folder = self.folder {
      itemsToSortOptional = folder.items
    } else {
      itemsToSortOptional = self.library.items
    }

    guard let itemsToSort = itemsToSortOptional,
          itemsToSort.count > 0 else { return }

    let sortedItems = BookSortService.sort(itemsToSort, by: option)

    if let folder = folder {
      folder.items = sortedItems
      folder.rebuildOrderRank()
    } else {
      self.library.items = sortedItems
      self.library.rebuildOrderRank()
    }

    self.dataManager.saveContext()

    self.reloadItems()
  }

  func handleRename(item: SimpleLibraryItem, with newTitle: String) {
    guard let libraryItem = self.dataManager.getItem(with: item.relativePath) else {
      return
    }

    self.dataManager.renameItem(libraryItem, with: newTitle)

    self.coordinator.reloadItemsWithPadding()
  }

  func handleResetPlaybackPosition(for items: [SimpleLibraryItem]) {
    let selectedItems = items.compactMap({ self.dataManager.getItem(with: $0.relativePath )})

    for item in selectedItems {
      self.dataManager.jumpToStart(item)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleMarkAsFinished(for items: [SimpleLibraryItem], flag: Bool) {
    let selectedItems = items.compactMap({ self.dataManager.getItem(with: $0.relativePath )})

    for item in selectedItems {
      self.dataManager.mark(item, asFinished: flag)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleDownload(_ url: URL) {
    NetworkService.shared.download(from: url) { response in
      NotificationCenter.default.post(name: .downloadEnd, object: self)

      if response.error != nil,
         let error = response.error {
        self.coordinator.showAlert("network_error_title".localized, message: error.localizedDescription)
      }

      if let response = response.response, response.statusCode >= 300 {
        self.coordinator.showAlert("network_error_title".localized, message: "Code \(response.statusCode)")
      }
    }
  }
}
