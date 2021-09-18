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

  func getPlaybackState(for item: LibraryItem) -> PlaybackState {
    guard let book = self.player.currentBook else {
      return .stopped
    }

    return book.relativePath.contains(item.relativePath) ? .playing : .stopped
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

  func showItemContents(_ item: SimpleLibraryItem) {
    guard let libraryItem = DataManager.getItem(with: item.relativePath) else {
      return
    }

    self.coordinator.showItemContents(libraryItem)
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
    if let mainCoordinator = self.coordinator?.parentCoordinator as? MainCoordinator {
      mainCoordinator.showMiniPlayer(flag)
    }
  }
}
