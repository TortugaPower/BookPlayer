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
import Themeable

class FolderListViewModel {
  weak var coordinator: FolderListCoordinator!
  let folder: Folder
  let library: Library
  let pageSize = 10
  var offset = 0

  var items = CurrentValueSubject<[SimpleLibraryItem], Never>([])
  private var defaultArtwork: Data?

  init(folder: Folder,
       library: Library,
       theme: Theme) {
    self.folder = folder
    self.library = library

    self.defaultArtwork = DefaultArtworkFactory.generateArtwork(from: theme.linkColor)?.pngData()
  }

  func getInitialItems() -> [SimpleLibraryItem] {
    guard let fetchedItems = DataManager.fetchContents(of: self.folder, limit: self.pageSize, offset: 0) else {
      return []
    }

    let displayItems = fetchedItems.map({ SimpleLibraryItem(from: $0, defaultArtwork: self.defaultArtwork) })
    self.offset = displayItems.count
    self.items.value = displayItems

    return displayItems
  }

  func loadNextItems() {
    guard let fetchedItems = DataManager.fetchContents(of: self.folder, limit: self.pageSize, offset: self.offset),
          !fetchedItems.isEmpty else {
      return
    }

    let displayItems = fetchedItems.map({ SimpleLibraryItem(from: $0, defaultArtwork: self.defaultArtwork) })
    self.offset += displayItems.count

    self.items.value += displayItems
  }

  func updateDefaultArtwork(for theme: Theme) {
    self.defaultArtwork = DefaultArtworkFactory.generateArtwork(from: theme.linkColor)?.pngData()
    self.items.value = self.items.value.map({ SimpleLibraryItem(from: $0, defaultArtwork: self.defaultArtwork) })
  }
}
