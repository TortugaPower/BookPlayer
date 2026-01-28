//
//  SearchViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

struct SearchSection {
  let folderName: String?
  let items: [SimpleLibraryItem]
  
  var displayName: String {
    return folderName ?? "library_title".localized
  }
}

@MainActor
class SearchViewModel: ObservableObject {
  @Published var searchText = ""
  @Published var recentItems: [SimpleLibraryItem] = []
  @Published var searchSections: [SearchSection] = []
  
  private let libraryService: LibraryService
  private var searchCancellable: AnyCancellable?
  
  var filteredRecentItems: [SimpleLibraryItem] {
    var filteredItems = recentItems
    
    if !searchText.isEmpty {
      filteredItems = filteredItems.filter {
        $0.title.localizedCaseInsensitiveContains(searchText) || $0.details.localizedCaseInsensitiveContains(searchText)
      }
    }
    
    return filteredItems
  }

  init(libraryService: LibraryService) {
    self.libraryService = libraryService
  }
  
  func loadRecentItems() {
    let items = libraryService.getLastPlayedItems(limit: 8) ?? []
    self.recentItems = items
  }
  
  func searchBooks(query: String) {
    // Cancel previous search
    searchCancellable?.cancel()
    
    // Always update the search based on current scope, even if query is empty
    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      searchSections = []
      return
    }
    
    // Debounce search to avoid too many requests
    searchCancellable = Timer.publish(every: 0.3, on: .main, in: .common)
      .autoconnect()
      .first()
      .sink { [weak self] _ in
        self?.performSearch(query: query)
      }
  }
  
  func searchWithCurrentScope() {
    searchBooks(query: searchText)
  }
  
  private func performSearch(query: String) {
    let allResults: [SimpleLibraryItem] = libraryService.searchAllBooks(
      query: query,
      limit: nil,
      offset: nil
    ) ?? []

    // Process results to handle bound books properly
    let processedResults = processBoundBookResults(allResults)

    // Group results by parent folder
    let groupedResults = groupResultsByFolder(processedResults)

    self.searchSections = groupedResults
  }

  /// When a book inside a bound folder matches, replace it with the bound folder itself.
  /// Bound books should appear as single items, not as sections with their internal chapters.
  private func processBoundBookResults(_ items: [SimpleLibraryItem]) -> [SimpleLibraryItem] {
    var resultItems: [SimpleLibraryItem] = []
    var addedBoundPaths: Set<String> = []

    for item in items {
      // Check if this item is inside a bound book
      if let parentPath = item.parentFolder,
         let parentType = libraryService.getItemProperty("type", relativePath: parentPath) as? Int16,
         parentType == SimpleItemType.bound.rawValue {
        // Parent is a bound book - add the parent instead (if not already added)
        if !addedBoundPaths.contains(parentPath) {
          if let boundItem = libraryService.getSimpleItem(with: parentPath) {
            resultItems.append(boundItem)
            addedBoundPaths.insert(parentPath)
          }
        }
      } else {
        // Regular item or bound book itself - add directly
        resultItems.append(item)
      }
    }

    return resultItems
  }
  
  private func groupResultsByFolder(_ items: [SimpleLibraryItem]) -> [SearchSection] {
    let grouped = Dictionary(grouping: items) { item in
      return item.parentFolder
    }
    
    return grouped.map { folderName, items in
      SearchSection(folderName: folderName, items: items)
    }.sorted { lhs, rhs in
      // Sort sections: Library (nil) first, then alphabetically
      if lhs.folderName == nil && rhs.folderName != nil {
        return true
      } else if lhs.folderName != nil && rhs.folderName == nil {
        return false
      } else {
        return (lhs.folderName ?? "") < (rhs.folderName ?? "")
      }
    }
  }
}
