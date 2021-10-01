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

class FolderListViewModel {
  weak var coordinator: ItemListCoordinator!
  let folder: Folder?
  let library: Library
  let player: PlayerManager
  let dataManager: DataManager
  let pageSize = 15
  var offset = 0

  private var defaultArtwork: Data?
  var items = CurrentValueSubject<[SimpleLibraryItem], Never>([])
  private var bookSubscription: AnyCancellable?
  private var bookProgressSubscription: AnyCancellable?
  private var containingFolder: Folder?

  init(folder: Folder?,
       library: Library,
       player: PlayerManager,
       dataManager: DataManager,
       theme: SimpleTheme) {
    self.folder = folder
    self.library = library
    self.player = player
    self.dataManager = dataManager

    self.defaultArtwork = DefaultArtworkFactory.generateArtwork(from: theme.linkColor)?.pngData()
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
      if let item = self.items.value.first(where: { book.relativePath.contains($0.relativePath) && $0.type == .folder }) {
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
              let index = self.items.value.firstIndex(where: { relativePath.contains($0.relativePath) }) else { return }

        let currentItem = self.items.value[index]

        var progress: Double?

        switch currentItem.type {
        case .book:
          progress = percentCompleted / 100
        case .folder:
          progress = self.containingFolder?.progressPercentage
        }

        let updatedItem = SimpleLibraryItem(from: currentItem, progress: progress, playbackState: .playing)

        self.items.value[index] = updatedItem
      })
  }

  func clearPlaybackState() {
    self.items.value = self.items.value.map({ SimpleLibraryItem(from: $0, playbackState: .stopped) })
  }

  func getInitialItems() -> [SimpleLibraryItem] {
    guard let fetchedItems = self.dataManager.fetchContents(of: self.folder,
                                                            or: library,
                                                            limit: self.pageSize,
                                                            offset: 0) else {
      return []
    }

    let displayItems = fetchedItems.map({ SimpleLibraryItem(
                                          from: $0,
                                          defaultArtwork: self.defaultArtwork,
                                          playbackState: self.getPlaybackState(for: $0)) })
    self.offset = displayItems.count
    self.items.value = displayItems

    return displayItems
  }

  func loadNextItems() {
    guard let fetchedItems = self.dataManager.fetchContents(of: self.folder, or: library, limit: self.pageSize, offset: self.offset),
          !fetchedItems.isEmpty else {
      return
    }

    let displayItems = fetchedItems.map({ SimpleLibraryItem(
                                          from: $0,
                                          defaultArtwork: self.defaultArtwork,
                                          playbackState: self.getPlaybackState(for: $0)) })
    self.offset += displayItems.count

    self.items.value += displayItems
  }

  func reloadItems() {
    _ = self.getInitialItems()
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

  func importIntoFolder(with title: String, items: [LibraryItem]? = nil) {
    do {
      let folder = try self.dataManager.createFolder(with: title, in: self.folder, library: self.library)
      if let items = items {
        try self.dataManager.moveItems(items, into: folder)
      }
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.reloadItems()
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

    self.reloadItems()
  }

  func handleMoveIntoLibrary(items: [SimpleLibraryItem]) {
    let selectedItems = items.compactMap({ self.dataManager.getItem(with: $0.relativePath )})

    do {
      try self.dataManager.moveItems(selectedItems, into: self.library)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.reloadItems()
  }

  func handleMoveIntoFolder(_ folder: SimpleLibraryItem, items: [SimpleLibraryItem]) {
    guard let storedFolder = self.dataManager.getItem(with: folder.relativePath) as? Folder else { return }

    let fetchedItems = items.compactMap({ self.dataManager.getItem(with: $0.relativePath )})

    do {
      try self.dataManager.moveItems(fetchedItems, into: storedFolder)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.reloadItems()
  }

  func handleDelete(items: [SimpleLibraryItem], mode: DeleteMode) {
    let selectedItems = items.compactMap({ self.dataManager.getItem(with: $0.relativePath )})

    do {
      try self.dataManager.delete(selectedItems, library: self.library, mode: mode)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.reloadItems()
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

    self.reloadItems()

    self.coordinator.showOperationCompletedAlert(with: processedItems)
  }

  func handleInsertionIntoLibrary(_ items: [LibraryItem]) {
    do {
      try self.dataManager.moveItems(items, into: self.library)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.reloadItems()
  }

  func reorder(item: SimpleLibraryItem, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {
    // TODO: reorder is broken, DB migration required to handle rank manually
//    guard let libraryItem = self.folder.items?.object(at: sourceIndexPath.row) as? LibraryItem,
//          item.relativePath == libraryItem.relativePath else { return }
//
//    self.folder.removeFromItems(at: sourceIndexPath.row)
//    self.folder.insertIntoItems(libraryItem, at: destinationIndexPath.row)

    // TODO: Handle when inserting into library

    self.dataManager.saveContext()
    MPPlayableContentManager.shared().reloadData()
  }

  func updateDefaultArtwork(for theme: SimpleTheme) {
    self.defaultArtwork = DefaultArtworkFactory.generateArtwork(from: theme.linkColor)?.pngData()
  }

  func getMiniPlayerOffset() -> CGFloat {
    return self.coordinator.miniPlayerOffset
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

        availableFolders.append(SimpleLibraryItem(from: folder, defaultArtwork: self.defaultArtwork))
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

        availableFolders.append(SimpleLibraryItem(from: folder, defaultArtwork: self.defaultArtwork))
      }
    }

    self.coordinator.showMoreOptionsAlert(selectedItems: selectedItems, availableFolders: availableFolders)
  }

  func handleSort(by option: PlayListSortOrder) {
    // TODO: This must be reworked after the manual rank migration is done
    let orderedSet = NSOrderedSet(array: self.items.value)
    guard let sortedItems = BookSortService.sort(orderedSet, by: option).array as? [SimpleLibraryItem] else {
      return
    }

    self.items.value = sortedItems
  }

  func handleRename(item: SimpleLibraryItem, with newTitle: String) {
    guard let libraryItem = self.dataManager.getItem(with: item.relativePath) else {
      return
    }

    self.dataManager.renameItem(libraryItem, with: newTitle)

    self.reloadItems()
  }

  func handleResetPlaybackPosition(for items: [SimpleLibraryItem]) {
    let selectedItems = items.compactMap({ self.dataManager.getItem(with: $0.relativePath )})

    for item in selectedItems {
      self.dataManager.jumpToStart(item)
    }

    self.reloadItems()
  }

  func handleMarkAsFinished(for items: [SimpleLibraryItem], flag: Bool) {
    let selectedItems = items.compactMap({ self.dataManager.getItem(with: $0.relativePath )})

    for item in selectedItems {
      self.dataManager.mark(item, asFinished: flag)
    }

    self.reloadItems()
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
