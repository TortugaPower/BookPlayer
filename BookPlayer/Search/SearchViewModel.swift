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

    // Group results by parent folder
    let groupedResults = groupResultsByFolder(allResults)
    
    self.searchSections = groupedResults
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
