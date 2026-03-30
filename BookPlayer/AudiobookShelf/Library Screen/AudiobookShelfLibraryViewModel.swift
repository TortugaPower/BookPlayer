//
//  AudiobookShelfLibraryViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import SwiftUI

protocol AudiobookShelfLibraryViewModelProtocol: ObservableObject {
  var navigation: BPNavigation { get set }
  var navigationTitle: String { get }
  var layout: AudiobookShelfLayout.Options { get set }
  var sortBy: AudiobookShelfLayout.SortBy { get set }

  var items: [AudiobookShelfLibraryItem] { get set }
  var totalItems: Int { get }
  var error: Error? { get set }

  var editMode: EditMode { get set }
  var selectedItems: Set<AudiobookShelfLibraryItem.ID> { get set }

  var searchQuery: String { get set }
  var isSearchable: Bool { get }
  var isGridEnabled: Bool { get }
  var showsLayoutPreferences: Bool { get }
  var showsSortPreferences: Bool { get }
  var allowsEditing: Bool { get }

  var connectionService: AudiobookShelfConnectionService { get }

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: AudiobookShelfLibraryItem)
  func cancelFetchItems()
  func destination(for item: AudiobookShelfLibraryItem) -> AudiobookShelfLibraryLevelData?

  @MainActor
  func handleDoneAction()

  @MainActor
  func onEditToggleSelectTapped()
  @MainActor
  func onSelectTapped(for item: AudiobookShelfLibraryItem)
  @MainActor
  func onSelectAllTapped()
  @MainActor
  func onDownloadTapped()
}

enum AudiobookShelfLayout {
  enum Options: String {
    case grid, list
  }

  enum SortBy: String {
    case recent, title
  }
}

final class AudiobookShelfLibraryViewModel: AudiobookShelfLibraryViewModelProtocol, BPLogger {
  enum Routes {
    case done
  }

  var navigation: BPNavigation
  let navigationTitle: String
  let source: AudiobookShelfLibraryViewSource

  @AppStorage(Constants.UserDefaults.audiobookshelfLibraryLayout)
  var layout: AudiobookShelfLayout.Options = .grid

  @AppStorage(Constants.UserDefaults.audiobookshelfLibraryLayoutSortBy)
  var sortBy: AudiobookShelfLayout.SortBy = .recent {
    didSet {
      handleSortChanged()
    }
  }

  @Published var searchQuery = ""
  @Published var items: [AudiobookShelfLibraryItem] = []
  @Published var totalItems = Int.max
  @Published var error: Error?

  @Published var editMode: EditMode = .inactive
  @Published var selectedItems: Set<AudiobookShelfLibraryItem.ID> = []

  var onTransition: BPTransition<Routes>?

  let connectionService: AudiobookShelfConnectionService
  private let singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?
  private var nextPage = 0
  private var allItems: [AudiobookShelfLibraryItem] = []

  private static let itemBatchSize = 20
  private static let itemFetchMargin = 3
  private static let searchResultLimit = 500

  private var disposeBag = Set<AnyCancellable>()

  var isSearchable: Bool {
    switch source {
    case .books(_, .none):
      true
    case .books(_, _), .entities(_, _), .collection(_):
      true
    case .libraries, .browseCategories(_):
      false
    }
  }

  var isGridEnabled: Bool {
    switch source {
    case .libraries, .books(_, _), .collection(_):
      true
    case .browseCategories(_), .entities(_, _):
      false
    }
  }

  var showsLayoutPreferences: Bool {
    isGridEnabled
  }

  var showsSortPreferences: Bool {
    switch source {
    case .books(_, _), .collection(_):
      true
    case .libraries, .browseCategories(_), .entities(_, _):
      false
    }
  }

  var allowsEditing: Bool {
    switch source {
    case .books(_, _), .collection(_):
      true
    case .libraries, .browseCategories(_), .entities(_, _):
      false
    }
  }

  private var usesRemoteBookSearch: Bool {
    if case .books(_, .none) = source {
      return true
    }
    return false
  }

  private var usesPagedFetching: Bool {
    if case .books(_, .none) = source, searchQuery.isEmpty {
      return true
    }
    return false
  }

  private var canFetchMoreItems: Bool {
    usesPagedFetching && items.count < totalItems
  }

  init(
    source: AudiobookShelfLibraryViewSource,
    connectionService: AudiobookShelfConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    navigation: BPNavigation,
    navigationTitle: String
  ) {
    self.source = source
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.navigation = navigation
    self.navigationTitle = navigationTitle

    $searchQuery
      .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
      .removeDuplicates()
      .dropFirst()
      .sink { [weak self] _ in
        self?.onSearchQueryChanged()
      }
      .store(in: &disposeBag)
  }

  func fetchInitialItems() {
    guard items.isEmpty, fetchTask == nil else { return }
    fetchSourceItems()
  }

  func fetchMoreItemsIfNeeded(currentItem: AudiobookShelfLibraryItem) {
    guard canFetchMoreItems, items.count >= Self.itemFetchMargin else { return }
    let thresholdIndex = items.index(items.endIndex, offsetBy: -Self.itemFetchMargin)
    if items.firstIndex(where: { $0.id == currentItem.id }) == thresholdIndex {
      fetchBooksPage()
    }
  }

  func cancelFetchItems() {
    fetchTask?.cancel()
    fetchTask = nil
  }

  func destination(for item: AudiobookShelfLibraryItem) -> AudiobookShelfLibraryLevelData? {
    switch item.kind {
    case .audiobook, .podcast:
      return .details(data: item)
    case .library:
      return .library(source: .browseCategories(library: item), title: item.title)
    case .browseCategory:
      guard let category = item.browseCategory else { return nil }
      switch category {
      case .books:
        return .library(source: .books(libraryID: item.libraryId, filter: nil), title: category.title)
      case .series, .collections, .authors, .narrators:
        return .library(source: .entities(libraryID: item.libraryId, category: category), title: category.title)
      }
    case .collection:
      return .library(source: .collection(id: item.id), title: item.title)
    case .author, .series, .narrator:
      guard let filter = item.filter else { return nil }
      return .library(source: .books(libraryID: item.libraryId, filter: filter), title: item.title)
    }
  }

  @MainActor
  func handleDoneAction() {
    onTransition?(.done)
  }

  @MainActor
  func onEditToggleSelectTapped() {
    guard allowsEditing else { return }

    withAnimation {
      editMode = editMode.isEditing ? .inactive : .active
    }

    if !editMode.isEditing {
      selectedItems.removeAll()
    }
  }

  @MainActor
  func onSelectTapped(for item: AudiobookShelfLibraryItem) {
    guard item.isDownloadable else { return }

    if let index = selectedItems.firstIndex(of: item.id) {
      selectedItems.remove(at: index)
    } else {
      selectedItems.insert(item.id)
    }
  }

  @MainActor
  func onSelectAllTapped() {
    guard allowsEditing else { return }

    if selectedItems.isEmpty {
      let ids = items.compactMap { item in
        item.isDownloadable ? item.id : nil
      }
      selectedItems = Set(ids)
    } else {
      selectedItems.removeAll()
    }
  }

  @MainActor
  func onDownloadTapped() {
    let items = selectedItems.compactMap { id in
      self.items.first(where: { $0.id == id && $0.isDownloadable })
    }

    var urls = [URL]()
    for item in items {
      do {
        let url = try connectionService.createItemDownloadUrl(item)
        urls.append(url)
      } catch {
        self.error = error
      }
    }

    guard !urls.isEmpty else { return }
    singleFileDownloadService.handleDownload(urls)
    navigation.dismiss?()
  }

  private func handleSortChanged() {
    guard !items.isEmpty else { return }

    switch source {
    case .books(let libraryID, .none):
      resetForFreshFetch()
      fetchBookItems(libraryID: libraryID, filter: nil)
    default:
      applyLocalSearchAndSort()
    }
  }

  private func fetchSourceItems() {
    switch source {
    case .libraries:
      fetchLibraries()
    case .browseCategories(let library):
      loadLocalItems(AudiobookShelfBrowseCategory.allCases.map {
        AudiobookShelfLibraryItem(category: $0, libraryId: library.id)
      })
    case .books(let libraryID, let filter):
      fetchBookItems(libraryID: libraryID, filter: filter)
    case .entities(let libraryID, let category):
      fetchEntityItems(libraryID: libraryID, category: category)
    case .collection(let id):
      fetchCollectionItems(collectionID: id)
    }
  }

  private func fetchLibraries() {
    fetchTask?.cancel()
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }

      do {
        let libraries = try await connectionService.fetchLibraries()
        let libraryItems = libraries
          .filter { $0.mediaType == "book" }
          .map(AudiobookShelfLibraryItem.init(library:))
        loadLocalItems(libraryItems)

        if libraryItems.count == 1, let library = libraryItems.first {
          navigation.path.append(
            AudiobookShelfLibraryLevelData.library(
              source: AudiobookShelfLibraryViewSource.browseCategories(library: library),
              title: library.title
            )
          )
        }
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  private func fetchEntityItems(libraryID: String, category: AudiobookShelfBrowseCategory) {
    fetchTask?.cancel()
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }

      do {
        switch category {
        case .books:
          loadLocalItems([])
        case .authors:
          let filterData = try await connectionService.fetchFilterData(in: libraryID)
          loadLocalItems(filterData.authors.map { AudiobookShelfLibraryItem(author: $0, libraryId: libraryID) })
        case .series:
          let filterData = try await connectionService.fetchFilterData(in: libraryID)
          loadLocalItems(filterData.series.map { AudiobookShelfLibraryItem(series: $0, libraryId: libraryID) })
        case .narrators:
          let filterData = try await connectionService.fetchFilterData(in: libraryID)
          loadLocalItems(filterData.narrators.map { AudiobookShelfLibraryItem(narrator: $0, libraryId: libraryID) })
        case .collections:
          let collections = try await connectionService.fetchCollections(in: libraryID)
          loadLocalItems(collections.map(AudiobookShelfLibraryItem.init(collection:)))
        }
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  private func fetchCollectionItems(collectionID: String) {
    fetchTask?.cancel()
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }

      do {
        let collection = try await connectionService.fetchCollection(id: collectionID)
        let books = collection.books.compactMap(AudiobookShelfLibraryItem.init(apiItem:))
        loadLocalItems(books)
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  private func fetchBookItems(libraryID: String, filter: AudiobookShelfItemFilter?) {
    resetSelectionState()

    if filter == nil, usesRemoteBookSearch, searchQuery.isEmpty {
      fetchBooksPage()
    } else if filter == nil, usesRemoteBookSearch {
      searchLibraryItems(libraryID: libraryID, query: searchQuery)
    } else {
      fetchAllFilteredBooks(libraryID: libraryID, filter: filter)
    }
  }

  private func fetchBooksPage() {
    guard case .books(let libraryID, let filter) = source else { return }
    guard filter == nil, fetchTask == nil, canFetchMoreItems else { return }

    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }

      do {
        let (items, totalItems) = try await connectionService.fetchItems(
          in: libraryID,
          limit: Self.itemBatchSize,
          page: nextPage,
          sortBy: sortParameter,
          desc: sortDescending,
          filter: nil
        )

        self.nextPage += 1
        self.totalItems = totalItems
        self.items.append(contentsOf: items)
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  private func fetchAllFilteredBooks(libraryID: String, filter: AudiobookShelfItemFilter?) {
    fetchTask?.cancel()
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }

      do {
        let (items, _) = try await connectionService.fetchItems(
          in: libraryID,
          limit: 0,
          page: 0,
          sortBy: sortParameter,
          desc: sortDescending,
          filter: filter
        )

        loadLocalItems(items)
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  private func searchLibraryItems(libraryID: String, query: String) {
    fetchTask?.cancel()
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }

      do {
        let items = try await connectionService.searchItems(
          in: libraryID,
          query: query,
          limit: Self.searchResultLimit
        )

        self.totalItems = items.count
        self.items = sortItems(items)
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  private func onSearchQueryChanged() {
    switch source {
    case .books(let libraryID, .none):
      resetForFreshFetch()

      if searchQuery.isEmpty {
        fetchBookItems(libraryID: libraryID, filter: nil)
      } else {
        searchLibraryItems(libraryID: libraryID, query: searchQuery)
      }
    default:
      applyLocalSearchAndSort()
    }
  }

  private func loadLocalItems(_ items: [AudiobookShelfLibraryItem]) {
    allItems = items
    applyLocalSearchAndSort()
  }

  private func applyLocalSearchAndSort() {
    let normalizedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    let filteredItems = normalizedQuery.isEmpty
      ? allItems
      : allItems.filter { item in
        item.title.localizedCaseInsensitiveContains(normalizedQuery)
          || item.subtitle?.localizedCaseInsensitiveContains(normalizedQuery) == true
          || item.authorName?.localizedCaseInsensitiveContains(normalizedQuery) == true
          || item.narratorName?.localizedCaseInsensitiveContains(normalizedQuery) == true
      }

    let sortedItems = sortItems(filteredItems)
    totalItems = sortedItems.count
    items = sortedItems
  }

  private func sortItems(_ items: [AudiobookShelfLibraryItem]) -> [AudiobookShelfLibraryItem] {
    switch sortBy {
    case .recent:
      return items.sorted { lhs, rhs in
        let lhsDate = lhs.updatedAt ?? lhs.addedAt ?? 0
        let rhsDate = rhs.updatedAt ?? rhs.addedAt ?? 0
        if lhsDate == rhsDate {
          return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return lhsDate > rhsDate
      }
    case .title:
      return items.sorted {
        $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
      }
    }
  }

  private func resetSelectionState() {
    editMode = .inactive
    selectedItems.removeAll()
  }

  private func resetForFreshFetch() {
    fetchTask?.cancel()
    fetchTask = nil
    resetSelectionState()
    items = []
    totalItems = Int.max
    nextPage = 0
  }

  private var sortParameter: String {
    switch sortBy {
    case .recent:
      "addedAt"
    case .title:
      "media.metadata.title"
    }
  }

  private var sortDescending: Bool? {
    switch sortBy {
    case .recent:
      true
    case .title:
      nil
    }
  }
}
