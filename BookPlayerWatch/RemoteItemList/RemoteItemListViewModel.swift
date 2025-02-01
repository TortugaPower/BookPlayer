//
//  RemoteItemListViewModel.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 28/1/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import Combine
import Foundation

@MainActor
final class RemoteItemListViewModel: ObservableObject {
  @Published var items: [SimpleLibraryItem]
  @Published var lastPlayedItem: SimpleLibraryItem?
  @Published var playingItemParentPath: String?
  @Published var playerManager: PlayerManager

  let coreServices: CoreServices
  let folderRelativePath: String?
  private var disposeBag = Set<AnyCancellable>()

  init(
    coreServices: CoreServices,
    folderRelativePath: String? = nil
  ) {
    self.coreServices = coreServices
    self.playerManager = coreServices.playerManager
    self.folderRelativePath = folderRelativePath
    /// initial load of data
    let fetchedItems =
      coreServices.libraryService.fetchContents(
        at: folderRelativePath,
        limit: nil,
        offset: nil
      ) ?? []
    self._items = .init(initialValue: fetchedItems)
    let lastItem = coreServices.libraryService.getLastPlayedItems(limit: 1)?.first

    if let lastItem {
      self._lastPlayedItem = .init(initialValue: lastItem)
      self._playingItemParentPath = .init(
        initialValue: getPathForParentOfItem(currentPlayingPath: lastItem.relativePath)
      )
    } else {
      self._lastPlayedItem = .init(initialValue: nil)
      self._playingItemParentPath = .init(initialValue: nil)
    }

    self.bindCurrentItemObserver()
  }

  func bindCurrentItemObserver() {
    playerManager.currentItemPublisher()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] currentItem in
        guard let self else { return }

        if let currentItem,
           let lastPlayedItem = self.coreServices.libraryService.getSimpleItem(with: currentItem.relativePath) {
          self.lastPlayedItem = lastPlayedItem
        } else {
          self.lastPlayedItem = coreServices.libraryService.getLastPlayedItems(limit: 1)?.first
        }
      }
      .store(in: &disposeBag)
  }

  func getPathForParentOfItem(currentPlayingPath: String) -> String? {
    let parentFolders: [String] = currentPlayingPath.allRanges(of: "/")
      .map { String(currentPlayingPath.prefix(upTo: $0.lowerBound)) }
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

  func syncListContents(ignoreLastTimestamp: Bool) async throws {
    guard
      await coreServices.syncService.canSyncListContents(
        at: folderRelativePath,
        ignoreLastTimestamp: ignoreLastTimestamp
      )
    else { return }

    do {
      try await coreServices.syncService.syncListContents(at: folderRelativePath)
    } catch BPSyncError.reloadLastBook(let relativePath) {
      try await reloadLastBook(relativePath: relativePath)
    } catch BPSyncError.differentLastBook(let relativePath) {
      try await setSyncedLastPlayedItem(relativePath: relativePath)
    } catch {
      throw error
    }

    items =
      coreServices.libraryService.fetchContents(
        at: folderRelativePath,
        limit: nil,
        offset: nil
      ) ?? []

    if let lastPlayedItem {
      playingItemParentPath = getPathForParentOfItem(currentPlayingPath: lastPlayedItem.relativePath)
    } else {
      playingItemParentPath = nil
    }
  }

  @MainActor
  private func reloadLastBook(relativePath: String) async throws {
    let wasPlaying = playerManager.isPlaying
    playerManager.stop()

    try await coreServices.playerLoaderService.loadPlayer(
      relativePath,
      autoplay: wasPlaying
    )
  }

  @MainActor
  private func setSyncedLastPlayedItem(relativePath: String) async throws {
    /// Only continue overriding local book if it's not currently playing
    guard playerManager.isPlaying == false else { return }

    await coreServices.syncService.setLibraryLastBook(with: relativePath)

    try await coreServices.playerLoaderService.loadPlayer(
      relativePath,
      autoplay: false
    )
  }
}
