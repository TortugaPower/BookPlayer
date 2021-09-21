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
  weak var coordinator: FolderListCoordinator!
  let folder: Folder
  let library: Library
  let player: PlayerManager
  let pageSize = 10
  var offset = 0

  private var defaultArtwork: Data?
  var items = CurrentValueSubject<[SimpleLibraryItem], Never>([])
  private var bookSubscription: AnyCancellable?
  private var bookProgressSubscription: AnyCancellable?
  private var containingFolder: Folder?

  init(folder: Folder,
       library: Library,
       player: PlayerManager,
       theme: Theme) {
    self.folder = folder
    self.library = library
    self.player = player

    self.defaultArtwork = DefaultArtworkFactory.generateArtwork(from: theme.linkColor)?.pngData()
    self.bindBookObserver()
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
    guard let fetchedItems = DataManager.fetchContents(of: self.folder, limit: self.pageSize, offset: 0) else {
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
    guard let fetchedItems = DataManager.fetchContents(of: self.folder, limit: self.pageSize, offset: self.offset),
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

  func getPlaybackState(for item: LibraryItem) -> PlaybackState {
    guard let book = self.player.currentBook else {
      return .stopped
    }

    return book.relativePath.contains(item.relativePath) ? .playing : .stopped
  }

  func showItemContents(_ item: SimpleLibraryItem) {
    guard let libraryItem = DataManager.getItem(with: item.relativePath) else {
      return
    }

    self.coordinator.showItemContents(libraryItem)
  }

  func importIntoFolder(with title: String, items: [LibraryItem]? = nil) {
    do {
      let folder = try DataManager.createFolder(with: title, in: self.folder, library: self.library)
      if let items = items {
        try DataManager.moveItems(items, into: folder)
      }
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.reloadItems()
  }

  func createFolder(with title: String, items: [SimpleLibraryItem]? = nil) {
    do {
      let folder = try DataManager.createFolder(with: title, in: self.folder, library: self.library)
      if let fetchedItems = items?.compactMap({ DataManager.getItem(with: $0.relativePath )}) {
        try DataManager.moveItems(fetchedItems, into: folder)
      }
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.reloadItems()
  }

  func handleMoveIntoLibrary(items: [SimpleLibraryItem]) {
    let selectedItems = items.compactMap({ DataManager.getItem(with: $0.relativePath )})

    do {
      try DataManager.moveItems(selectedItems, into: self.library)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.reloadItems()
  }

  func handleMoveIntoFolder(_ folder: SimpleLibraryItem, items: [SimpleLibraryItem]) {
    guard let storedFolder = DataManager.getItem(with: folder.relativePath) as? Folder else { return }

    let fetchedItems = items.compactMap({ DataManager.getItem(with: $0.relativePath )})

    do {
      try DataManager.moveItems(fetchedItems, into: storedFolder)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.reloadItems()
  }

  func handleOperationCompletion(_ files: [URL]) {
    let processedItems = DataManager.insertItems(from: files, into: nil, library: self.library)

    do {
      try DataManager.moveItems(processedItems, into: self.folder)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
      return
    }

    self.reloadItems()

    self.coordinator.showOperationCompletedAlert(with: processedItems)
  }

  func handleInsertionIntoLibrary(_ items: [LibraryItem]) {
    do {
      try DataManager.moveItems(items, into: self.library)
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }

    self.reloadItems()
  }

  func reorder(item: SimpleLibraryItem, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {
    // TODO: reorder is broken, DB migration required to handle rank manually
    guard let libraryItem = self.folder.items?.object(at: sourceIndexPath.row) as? LibraryItem,
          item.relativePath == libraryItem.relativePath else { return }

    self.folder.removeFromItems(at: sourceIndexPath.row)
    self.folder.insertIntoItems(libraryItem, at: destinationIndexPath.row)

    // TODO: Handle when inserting into library

    DataManager.saveContext()
    MPPlayableContentManager.shared().reloadData()
  }

  func updateDefaultArtwork(for theme: Theme) {
    self.defaultArtwork = DefaultArtworkFactory.generateArtwork(from: theme.linkColor)?.pngData()
    self.items.value = self.items.value.map({ SimpleLibraryItem(from: $0, defaultArtwork: self.defaultArtwork) })
  }

  func getMiniPlayerOffset() -> CGFloat {
    return self.coordinator.miniPlayerOffset
  }

  func showMiniPlayer(_ flag: Bool) {
    if let mainCoordinator = self.coordinator?.getMainCoordinator() {
      mainCoordinator.showMiniPlayer(flag)
    }
  }

  func showAddActions() {
    self.coordinator.showAddActions()
  }

  func handleNewFiles(_ urls: [URL]) {
    for url in urls {
      DataManager.processFile(at: url)
    }
  }

  func showSortOptions() {
    self.coordinator.showSortOptions()
  }

  func showMoveOptions(selectedItems: [SimpleLibraryItem]) {
    var availableFolders = [SimpleLibraryItem]()

    if let existingFolders = DataManager.fetchFolders(in: self.folder) {
      for folder in existingFolders {
        if selectedItems.contains(where: { $0.relativePath == folder.relativePath }) { continue }

        availableFolders.append(SimpleLibraryItem(from: folder, defaultArtwork: self.defaultArtwork))
      }
    }

    self.coordinator.showMoveOptions(selectedItems: selectedItems, availableFolders: availableFolders)
  }

  func handleSort(by option: PlayListSortOrder) {
    // TODO: This must be reworked after the manual rank migration is done
    let orderedSet = NSOrderedSet(array: self.items.value)
    guard let sortedItems = BookSortService.sort(orderedSet, by: option).array as? [SimpleLibraryItem] else {
      return
    }

    self.items.value = sortedItems
  }
}
