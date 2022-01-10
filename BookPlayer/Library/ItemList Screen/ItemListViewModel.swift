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
  private var themeAccent: UIColor
  public private(set) var itemsUpdates = PassthroughSubject<[SimpleLibraryItem], Never>()
  public private(set) var itemProgressUpdates = PassthroughSubject<IndexPath, Never>()
  public private(set) var items = [SimpleLibraryItem]()
  private var bookSubscription: AnyCancellable?
  private var bookProgressSubscription: AnyCancellable?
  private var containingFolder: Folder?

  public var maxItems: Int {
    return self.libraryService.getMaxItemsCount(at: self.folderRelativePath)
  }

  init(folderRelativePath: String?,
       playerManager: PlayerManagerProtocol,
       libraryService: LibraryServiceProtocol,
       themeAccent: UIColor) {
    self.folderRelativePath = folderRelativePath
    self.playerManager = playerManager
    self.libraryService = libraryService
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
    guard let folderRelativePath = folderRelativePath else {
      return "library_title".localized
    }

    guard let item = self.libraryService.getItem(with: folderRelativePath) else {
      return ""
    }

    return item.title
  }

  func bindBookObserver() {
    self.bookSubscription = self.playerManager.currentItemPublisher().sink { [weak self] currentItem in
      guard let self = self else { return }

      self.bookProgressSubscription?.cancel()
      self.containingFolder = nil

      guard let currentItem = currentItem else {
        self.clearPlaybackState()
        return
      }

      // Get folder reference for progress calculation
      if let item = self.items.first(where: { currentItem.relativePath.contains($0.relativePath) && $0.type == .folder }) {
        self.containingFolder = self.libraryService.findFolder(with: item.relativePath)
      }

      self.bindItemProgressObserver(currentItem)
    }
  }

  func bindItemProgressObserver(_ item: PlayableItem) {
    self.bookProgressSubscription?.cancel()

    self.bookProgressSubscription = item.publisher(for: \.percentCompleted)
      .combineLatest(item.publisher(for: \.relativePath))
      .removeDuplicates(by: { $0.0 == $1.0 })
      .sink(receiveValue: { [weak self] (percentCompleted, relativePath) in
        guard let self = self,
              let index = self.items.firstIndex(where: { relativePath.contains($0.relativePath) }) else { return }

        let currentItem = self.items[index]

        var progress: Double?

        switch currentItem.type {
        case .book, .bound:
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
    guard let fetchedItems = self.libraryService.fetchContents(at: self.folderRelativePath,
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

    guard let fetchedItems = self.libraryService.fetchContents(at: self.folderRelativePath,
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

    guard let fetchedItems = self.libraryService.fetchContents(at: self.folderRelativePath,
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
    guard let libraryItem = self.libraryService.getItem(with: item.relativePath) else {
      return
    }

    var pathToPlay: String?

    defer {
      if let pathToPlay = pathToPlay {
        self.coordinator.loadPlayer(pathToPlay)
      }
    }

    guard let folder = libraryItem as? Folder,
          folder.type == .regular else {
      pathToPlay = libraryItem.relativePath
      return
    }

    // Special treatment for folders
    guard
      let currentItem = self.playerManager.currentItem,
      currentItem.relativePath.contains(folder.relativePath) else {
        // restart the selected folder if current playing book has no relation to it
        if libraryItem.isFinished {
          self.libraryService.jumpToStart(relativePath: libraryItem.relativePath)
        }

        pathToPlay = libraryItem.getBookToPlay()?.relativePath
        return
      }

    // override next book with the one already playing
    pathToPlay = currentItem.relativePath
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
    guard let currentItem = self.playerManager.currentItem else {
      return .stopped
    }

    return currentItem.relativePath.contains(item.relativePath) ? .playing : .stopped
  }

  func showItemContents(_ item: SimpleLibraryItem) {
    self.coordinator.showItemContents(item)
  }

  func importIntoFolder(_ folder: SimpleLibraryItem, items: [LibraryItem], type: FolderType) {
    let fetchedItems = items.compactMap({ self.libraryService.getItem(with: $0.relativePath )})

    do {
      try self.libraryService.moveItems(fetchedItems, inside: folder.relativePath, moveFiles: true)
      try self.libraryService.updateFolder(at: folder.relativePath, type: type)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func createFolder(with title: String, items: [String]? = nil, type: FolderType) {
    do {
      let folder = try self.libraryService.createFolder(with: title, inside: self.folderRelativePath)
      if let fetchedItems = items?.compactMap({ self.libraryService.getItem(with: $0 )}) {
        try self.libraryService.moveItems(fetchedItems, inside: folder.relativePath, moveFiles: true)
      }
      try self.libraryService.updateFolder(at: folder.relativePath, type: type)

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

  func updateFolders(_ folders: [SimpleLibraryItem], type: FolderType) {
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

    do {
      try self.libraryService.moveItems(selectedItems, inside: nil, moveFiles: true)
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
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleDelete(items: [SimpleLibraryItem], mode: DeleteMode) {
    let selectedItems = items.compactMap({ self.libraryService.getItem(with: $0.relativePath )})

    do {
      let library = self.libraryService.getLibrary()
      try self.libraryService.delete(selectedItems, library: library, mode: mode)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleOperationCompletion(_ files: [URL]) {
    let library = self.libraryService.getLibrary()
    let processedItems = self.libraryService.insertItems(from: files, into: nil, library: library, processedItems: [])

    do {
      let shouldMoveFiles = self.folderRelativePath != nil

      try self.libraryService.moveItems(processedItems, inside: self.folderRelativePath, moveFiles: shouldMoveFiles)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
      return
    }

    self.coordinator.reloadItemsWithPadding(padding: processedItems.count)

    var availableFolders = [SimpleLibraryItem]()

    if let existingFolders = (self.libraryService.fetchContents(at: self.folderRelativePath, limit: nil, offset: nil)?
                                .compactMap({ $0 as? Folder })) {
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
      try self.libraryService.moveItems(items, inside: nil, moveFiles: true)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

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

  func showSettings() {
    self.coordinator.showSettings()
  }

  func showAddActions() {
    self.coordinator.showAddActions()
  }

  func notifyPendingFiles() {
    let documentsFolder = DataManager.getDocumentsFolderURL()
    let inboxFolder = DataManager.getInboxFolderURL()

    // Get reference of all the files located inside the Documents folder
    guard let urls = try? FileManager.default.contentsOfDirectory(at: documentsFolder, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) else {
      return
    }

    // Filter out Processed and Inbox folders from file URLs.
    var filteredUrls = urls.filter {
      $0.lastPathComponent != DataManager.processedFolderName
      && $0.lastPathComponent != DataManager.inboxFolderName
    }

    // Consider items in the Inbox folder
    if let inboxUrls = try? FileManager.default.contentsOfDirectory(at: inboxFolder, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) {
      filteredUrls += inboxUrls
    }

    guard !filteredUrls.isEmpty else { return }

    self.handleNewFiles(filteredUrls)
  }

  func handleNewFiles(_ urls: [URL]) {
    self.coordinator.processFiles(urls: urls)
  }

  func showSortOptions() {
    self.coordinator.showSortOptions()
  }

  func showMoveOptions(selectedItems: [SimpleLibraryItem]) {
    var availableFolders = [SimpleLibraryItem]()

    if let existingFolders = (self.libraryService.fetchContents(at: self.folderRelativePath, limit: nil, offset: nil)?
                                .compactMap({ $0 as? Folder })) {
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

    if let existingFolders = (self.libraryService.fetchContents(at: self.folderRelativePath, limit: nil, offset: nil)?
                                .compactMap({ $0 as? Folder })) {
      for folder in existingFolders {
        if selectedItems.contains(where: { $0.relativePath == folder.relativePath }) { continue }

        availableFolders.append(SimpleLibraryItem(from: folder, themeAccent: self.themeAccent))
      }
    }

    self.coordinator.showMoreOptionsAlert(selectedItems: selectedItems, availableFolders: availableFolders)
  }

  func handleSort(by option: PlayListSortOrder) {
    guard let itemsToSort = self.libraryService.fetchContents(at: self.folderRelativePath, limit: nil, offset: nil),
          itemsToSort.count > 0 else { return }

    let sortedItems = BookSortService.sort(NSOrderedSet(array: itemsToSort), by: option)

    self.libraryService.replaceOrderedItems(sortedItems, at: self.folderRelativePath)

    self.reloadItems()
  }

  func handleRename(item: SimpleLibraryItem, with newTitle: String) {
    self.libraryService.renameItem(at: item.relativePath, with: newTitle)

    self.coordinator.reloadItemsWithPadding()
  }

  func handleResetPlaybackPosition(for items: [SimpleLibraryItem]) {
    items.forEach({ self.libraryService.jumpToStart(relativePath: $0.relativePath) })

    self.coordinator.reloadItemsWithPadding()
  }

  func handleMarkAsFinished(for items: [SimpleLibraryItem], flag: Bool) {
    items.forEach({ self.libraryService.markAsFinished(flag: flag, relativePath: $0.relativePath) })

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
