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

class SearchListViewModel: BaseViewModel<SearchListCoordinator> {
  /// Available routes for this screen
  enum Routes {
    case itemSelected(item: SimpleLibraryItem)
  }

  /// Search only the folder if entered search via a subfolder
  let folderRelativePath: String?
  /// Title for the placeholder of space we're searching (e.g. Library, or folder name)
  let placeholderTitle: String
  /// Library service used to search the items
  let libraryService: LibraryServiceProtocol
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
  /// Callback to handle actions on this screen
  public var onTransition: Transition<Routes>?

  /// Initializer
  init(
    folderRelativePath: String?,
    placeholderTitle: String,
    libraryService: LibraryServiceProtocol,
    themeAccent: UIColor
  ) {
    self.folderRelativePath = folderRelativePath
    self.placeholderTitle = placeholderTitle
    self.libraryService = libraryService
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: themeAccent)?.pngData()
  }

  /// Get search scopes as String
  func getSearchScopes() -> [String] {
    return searchScopes.map { item in
      switch item {
      case .book, .bound:
        return "Books"
      case .folder:
        return "Folders"
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
    guard
      let fetchedItems = libraryService.filterContents(
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

  /// Pass callback with item selected
  func handleItemSelection(at index: Int) {
    let item = self.items.value[index]
    onTransition?(.itemSelected(item: item))
  }

  func updateDefaultArtwork(for theme: SimpleTheme) {
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: theme.linkColor)?.pngData()
  }
}
