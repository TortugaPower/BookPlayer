//
//  JellyfinLibraryViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-27.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import Get
import JellyfinAPI
import SwiftUI

enum JellyfinLibraryLevelData: Equatable, Hashable {
  case topLevel(libraryName: String)
  case folder(data: JellyfinLibraryItem)
  case authorBooks(authorID: String, authorName: String, parentID: String?)
  case narratorBooks(personID: String, personName: String, parentID: String?)
  case details(data: JellyfinLibraryItem)
  case subscribe
}

enum JellyfinLayout {
  enum SortBy: String {
    case recent, name, smart
  }
}

@MainActor
final class JellyfinLibraryViewModel: IntegrationLibraryViewModelProtocol, BPLogger {
  enum Routes {
    case done
  }

  var navigation: BPNavigation
  let navigationTitle: String

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayout)
  var layout: IntegrationLayout.Options = .grid

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayoutSortBy)
  var sortBy: JellyfinLayout.SortBy = .smart {
    didSet {
      guard let folderID = folderID else { return }
      items = []
      nextStartItemIndex = 0
      totalItems = Int.max
      fetchFolderItems(folderID: folderID)
    }
  }

  @Published var searchQuery = ""
  @Published var items: [JellyfinLibraryItem] = []
  @Published var totalItems = Int.max
  @Published var error: Error?

  @Published var editMode: EditMode = .inactive
  @Published var selectedItems: Set<JellyfinLibraryItem.ID> = []
  @Published var showingDownloadConfirmation = false

  var isSearchable: Bool { true }

  var useSelectedItems = false
  var onTransition: BPTransition<Routes>?

  let folderID: String?
  let recursive: Bool
  var importManager: ImportManager?
  let connectionService: JellyfinConnectionService
  let accountService: AccountService
  private let singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?
  private var nextStartItemIndex = 0

  private static let itemBatchSize = 20
  private static let itemFetchMargin = 3

  private var disposeBag = Set<AnyCancellable>()

  var canFetchMoreItems: Bool {
    nextStartItemIndex < totalItems
  }

  init(
    folderID: String?,
    recursive: Bool = false,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    importManager: ImportManager?,
    accountService: AccountService,
    navigation: BPNavigation,
    navigationTitle: String
  ) {
    self.folderID = folderID
    self.recursive = recursive
    self.connectionService = connectionService
    self.importManager = importManager
    self.singleFileDownloadService = singleFileDownloadService
    self.accountService = accountService
    self.navigation = navigation
    self.navigationTitle = navigationTitle

    $searchQuery
      .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
      .removeDuplicates()
      .dropFirst()
      .sink { [weak self] _ in
        self?.onSearchQueryChanged()
      }
      .store(in: &disposeBag)
  }

  func fetchInitialItems() {
    // Don't fetch if no folder is set (library not yet resolved)
    guard folderID != nil || !searchQuery.isEmpty else { return }
    fetchMoreItems()
  }

  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem) {
    guard items.count >= Self.itemFetchMargin,
          let idx = items.firstIndex(where: { $0.id == currentItem.id })
    else { return }
    let thresholdIndex = items.count - Self.itemFetchMargin
    if idx >= thresholdIndex {
      fetchMoreItems()
    }
  }

  func cancelFetchItems() {
    fetchTask?.cancel()
    fetchTask = nil
  }

  func destination(for item: JellyfinLibraryItem) -> JellyfinLibraryLevelData? {
    switch item.kind {
    case .audiobook:
      return .details(data: item)
    case .userView, .folder:
      return .folder(data: item)
    case .author:
      return .authorBooks(authorID: item.id, authorName: item.name, parentID: folderID)
    case .narrator:
      return .narratorBooks(personID: item.id, personName: item.name, parentID: folderID)
    }
  }

  private func fetchMoreItems() {
    guard fetchTask == nil && canFetchMoreItems else {
      return
    }

    if let folderID {
      fetchFolderItems(folderID: folderID)
    } else if !searchQuery.isEmpty {
      fetchGlobalSearchItems()
    } else {
      fetchTopLevelItems()
    }
  }

  private func fetchTopLevelItems() {
    fetchTask?.cancel()
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }
      items = []

      do {
        let items = try await connectionService.fetchTopLevelItems()

        self.totalItems = items.count
        self.items = items
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  private func onSearchQueryChanged() {
    fetchTask?.cancel()
    fetchTask = nil
    editMode = .inactive
    items = []
    selectedItems.removeAll()
    nextStartItemIndex = 0
    totalItems = Int.max

    if let folderID {
      fetchFolderItems(folderID: folderID)
    } else if searchQuery.isEmpty {
      fetchTopLevelItems()
    } else {
      fetchGlobalSearchItems()
    }
  }

  private func fetchGlobalSearchItems() {
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }

      let capturedQuery = searchQuery
      let previousNextStart = nextStartItemIndex
      do {
        let (newItems, nextStart, maxNumItems) = try await connectionService.fetchItems(
          in: nil,
          startIndex: nextStartItemIndex,
          limit: Self.itemBatchSize,
          sortBy: sortBy,
          searchTerm: capturedQuery
        )

        guard searchQuery == capturedQuery, !Task.isCancelled else { return }
        self.nextStartItemIndex = max(self.nextStartItemIndex, nextStart)
        self.items.append(contentsOf: newItems)
        let rawAdded = max(0, nextStart - previousNextStart)
        self.totalItems = updatedTotal(forRawAdded: rawAdded, serverTotal: maxNumItems)
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  private func fetchFolderItems(folderID: String) {
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }

      let capturedQuery = searchQuery
      let capturedFolderID = folderID
      let previousNextStart = nextStartItemIndex
      do {
        let searchParam: String? = capturedQuery.isEmpty ? nil : capturedQuery
        let (newItems, nextStart, maxNumItems) = try await connectionService.fetchItems(
          in: capturedFolderID,
          startIndex: nextStartItemIndex,
          limit: Self.itemBatchSize,
          sortBy: sortBy,
          searchTerm: searchParam,
          recursive: recursive
        )

        guard searchQuery == capturedQuery, !Task.isCancelled else { return }
        self.nextStartItemIndex = max(self.nextStartItemIndex, nextStart)
        self.items.append(contentsOf: newItems)
        let rawAdded = max(0, nextStart - previousNextStart)
        self.totalItems = updatedTotal(forRawAdded: rawAdded, serverTotal: maxNumItems)
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  /// Resolves the value to publish for `totalItems` after a paginated fetch.
  /// A short page (the server returned fewer raw items than we asked for) means
  /// we've reached the end. Otherwise prefer the server's total when available,
  /// falling back to a sentinel that keeps pagination alive without exposing
  /// `Int.max` to the UI.
  ///
  /// `rawAdded` must be the count *as returned by the server*, before any
  /// client-side filtering — otherwise dropped items would be mistaken for the
  /// end of the list.
  private func updatedTotal(forRawAdded rawAdded: Int, serverTotal: Int) -> Int {
    if rawAdded < Self.itemBatchSize {
      return self.items.count
    }
    if serverTotal < Int.max {
      return max(serverTotal, self.items.count)
    }
    return self.items.count + Self.itemBatchSize
  }

  @MainActor
  func handleDoneAction() {
    onTransition?(.done)
  }

  @MainActor
  func onEditToggleSelectTapped() {
    withAnimation {
      editMode = editMode.isEditing ? .inactive : .active
    }

    if !editMode.isEditing {
      selectedItems.removeAll()
    }
  }

  @MainActor
  func onSelectTapped(for item: JellyfinLibraryItem) {
    if let index = selectedItems.firstIndex(of: item.id) {
      selectedItems.remove(at: index)
    } else {
      selectedItems.insert(item.id)
    }
  }

  @MainActor
  func onSelectAllTapped() {
    if selectedItems.isEmpty {
      let ids: [JellyfinLibraryItem.ID] = items.compactMap { item in
        guard item.kind == .audiobook else { return nil }
        return item.id
      }

      selectedItems = Set(ids)
    } else {
      selectedItems.removeAll()
    }
  }
  
  @MainActor
  func handleImportItems(useSelectedItems: Bool) {
    if accountService.hasLiteEnabled() {
      virtualImportFolderAudiobooks(useSelectedItems: useSelectedItems)
    } else {
      if useSelectedItems {
        onDownloadTapped()
      } else {
        confirmDownloadFolder()
      }
    }
  }

  @MainActor
  func onDownloadTapped() {
    let items = selectedItems.compactMap({ id in
      self.items.first(where: { $0.id == id })
    })

    var requests = [URLRequest]()
    for item in items {
      do {
        let request = try connectionService.createItemDownloadRequest(item)
        requests.append(request)
      } catch {
        self.error = error
      }
    }
    singleFileDownloadService.handleDownload(requests)
    navigation.dismiss?()
  }

  @MainActor
  func onDownloadFolderTapped() {
    useSelectedItems = false
    showingDownloadConfirmation = true
  }

  @MainActor
  func confirmDownloadFolder() {
    guard let folderID else { return }

    Task { @MainActor [weak self] in
      guard let self else { return }

      do {
        let requests = try await self.getAllAudiobookDownloadRequests(for: folderID)
        self.singleFileDownloadService.handleDownload(requests, folderName: self.navigationTitle)
        self.navigation.dismiss?()
      } catch {
        self.error = error
      }
    }
  }

  @MainActor
  private func getAllAudiobookDownloadRequests(for folderID: String) async throws -> [URLRequest] {
    if items.count == totalItems {
      let audiobooks = items.filter { $0.kind == .audiobook }
      return audiobooks.compactMap { audiobook in
        try? connectionService.createItemDownloadRequest(audiobook)
      }
    } else {
      return try await connectionService.fetchAudiobookDownloadRequests(for: folderID)
    }
  }
  
  @MainActor
  func virtualImportFolderAudiobooks(useSelectedItems: Bool) {
    let audiobooks = useSelectedItems
    ? selectedItems.compactMap({ id in
      self.items.first(where: { $0.id == id })
    })
    : self.items.filter { $0.kind == .audiobook }
    
    let libraryItems: [SimpleExternalResource] = audiobooks.map { item in
      let fileExt = item.details?.filePath?.split(separator: ".").last ?? "m4a"
      let libraryItem = SimpleLibraryItem(
        title: item.name,
        details: item.details?.artist ?? "voiceover_unknown_author".localized,
        speed: 1, 
        currentTime: Double(item.currentSeconds ?? 0),
        duration: Double(item.durationSeconds ?? 0),
        percentCompleted: (item.durationSeconds ?? 0 > 0 && item.currentSeconds ?? 0 > 0)
          ? Double(item.currentSeconds!) / Double(item.durationSeconds!) : 0,
        isFinished: item.isFinished ?? false,
        relativePath: "",
        remoteURL: nil,
        artworkURL: try? connectionService.createItemImageURL(item, size: CGSize(width: 200, height: 200)),
        orderRank: 0,
        parentFolder: nil,
        originalFileName: "\(item.name).\(fileExt)",
        lastPlayDate: item.lastPlayedDate,
        type: .book,
        uuid: UUID().uuidString
      )
      
      let externalItem = SimpleExternalResource(
        id: UUID().hashValue,
        providerName: ExternalResource.ProviderName.jellyfin.rawValue,
        providerId: item.id,
        syncStatus: ExternalResource.SyncStatus.stream.rawValue,
        lastSyncedAt: nil,
        libraryItem: libraryItem
      )
      
      return externalItem
    }
    
    importManager?.externalFiles.append(contentsOf: libraryItems)
    importManager?.isShowingExternalImportView = true
  }
}

// MARK: - Author Books ViewModel

@MainActor
final class JellyfinAuthorBooksViewModel: IntegrationLibraryViewModelProtocol, BPLogger {
  let authorID: String
  let parentID: String?

  var navigation: BPNavigation
  let navigationTitle: String

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayout)
  var layout: IntegrationLayout.Options = .grid

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayoutSortBy)
  var sortBy: JellyfinLayout.SortBy = .smart

  @Published var searchQuery = ""
  @Published var items: [JellyfinLibraryItem] = []
  @Published var totalItems = Int.max
  @Published var error: Error?

  @Published var editMode: EditMode = .inactive
  @Published var selectedItems: Set<JellyfinLibraryItem.ID> = []
  @Published var showingDownloadConfirmation = false

  var isSearchable: Bool { true }

  var importManager: ImportManager?
  let connectionService: JellyfinConnectionService
  let accountService: AccountService
  private let singleFileDownloadService: SingleFileDownloadService
  private var fetchTask: Task<(), any Error>?
  private var allItems: [JellyfinLibraryItem] = []
  private var disposeBag = Set<AnyCancellable>()

  init(
    authorID: String,
    parentID: String?,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    importManager: ImportManager?,
    accountService: AccountService,
    navigation: BPNavigation,
    navigationTitle: String
  ) {
    self.authorID = authorID
    self.parentID = parentID
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.importManager = importManager
    self.accountService = accountService
    self.navigation = navigation
    self.navigationTitle = navigationTitle

    $searchQuery
      .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
      .removeDuplicates()
      .dropFirst()
      .sink { [weak self] _ in self?.applySearch() }
      .store(in: &disposeBag)
  }

  func fetchInitialItems() {
    guard items.isEmpty, fetchTask == nil else { return }
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }
      do {
        let (items, _, _) = try await connectionService.fetchItemsByArtist(
          artistID: authorID,
          parentID: parentID,
          startIndex: 0,
          limit: nil,
          sortBy: sortBy
        )
        self.allItems = items
        applySearch()
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem) {}

  func cancelFetchItems() {
    fetchTask?.cancel()
    fetchTask = nil
  }

  func destination(for item: JellyfinLibraryItem) -> JellyfinLibraryLevelData? {
    switch item.kind {
    case .audiobook: .details(data: item)
    case .folder: .folder(data: item)
    default: nil
    }
  }

  @MainActor func handleDoneAction() {}

  @MainActor
  func onEditToggleSelectTapped() {
    withAnimation {
      editMode = editMode.isEditing ? .inactive : .active
    }
    if !editMode.isEditing { selectedItems.removeAll() }
  }

  @MainActor
  func onSelectTapped(for item: JellyfinLibraryItem) {
    guard item.isDownloadable else { return }
    if selectedItems.contains(item.id) {
      selectedItems.remove(item.id)
    } else {
      selectedItems.insert(item.id)
    }
  }

  @MainActor
  func onSelectAllTapped() {
    if selectedItems.isEmpty {
      selectedItems = Set(items.compactMap { $0.isDownloadable ? $0.id : nil })
    } else {
      selectedItems.removeAll()
    }
  }

  @MainActor
  func onDownloadTapped() {
    let downloadItems = selectedItems.compactMap { id in
      items.first(where: { $0.id == id && $0.isDownloadable })
    }
    guard !downloadItems.isEmpty else { return }
    var requests = [URLRequest]()
    for item in downloadItems {
      do {
        let request = try connectionService.createItemDownloadRequest(item)
        requests.append(request)
      } catch {
        self.error = error
      }
    }
    guard !requests.isEmpty else { return }
    singleFileDownloadService.handleDownload(requests)
    navigation.dismiss?()
  }

  @MainActor func onDownloadFolderTapped() {}
  @MainActor func confirmDownloadFolder() {}

  private func applySearch() {
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    if query.isEmpty {
      items = allItems
    } else {
      items = allItems.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    totalItems = items.count
  }
}

// MARK: - Narrator Books ViewModel

@MainActor
final class JellyfinNarratorBooksViewModel: IntegrationLibraryViewModelProtocol, BPLogger {
  let personID: String
  let parentID: String?

  var navigation: BPNavigation
  let navigationTitle: String

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayout)
  var layout: IntegrationLayout.Options = .grid

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayoutSortBy)
  var sortBy: JellyfinLayout.SortBy = .smart

  @Published var searchQuery = ""
  @Published var items: [JellyfinLibraryItem] = []
  @Published var totalItems = Int.max
  @Published var error: Error?

  @Published var editMode: EditMode = .inactive
  @Published var selectedItems: Set<JellyfinLibraryItem.ID> = []
  @Published var showingDownloadConfirmation = false

  var isSearchable: Bool { true }
  
  var importManager: ImportManager? { get set }
  let accountService: AccountService
  let connectionService: JellyfinConnectionService
  private let singleFileDownloadService: SingleFileDownloadService
  private var fetchTask: Task<(), any Error>?
  private var allItems: [JellyfinLibraryItem] = []
  private var disposeBag = Set<AnyCancellable>()

  init(
    personID: String,
    parentID: String?,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    importManager: ImportManager?,
    accountService: AccountService,
    navigation: BPNavigation,
    navigationTitle: String
  ) {
    self.personID = personID
    self.parentID = parentID
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.importManager = importManager
    self.accountService = accountService
    self.navigation = navigation
    self.navigationTitle = navigationTitle

    $searchQuery
      .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
      .removeDuplicates()
      .dropFirst()
      .sink { [weak self] _ in self?.applySearch() }
      .store(in: &disposeBag)
  }

  func fetchInitialItems() {
    guard items.isEmpty, fetchTask == nil else { return }
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }
      do {
        let (items, _, _) = try await connectionService.fetchItemsByPerson(
          personID: personID,
          personName: navigationTitle,
          parentID: parentID,
          startIndex: 0,
          limit: nil,
          sortBy: sortBy
        )
        self.allItems = items
        applySearch()
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem) {}

  func cancelFetchItems() {
    fetchTask?.cancel()
    fetchTask = nil
  }

  func destination(for item: JellyfinLibraryItem) -> JellyfinLibraryLevelData? {
    switch item.kind {
    case .audiobook: .details(data: item)
    case .folder: .folder(data: item)
    default: nil
    }
  }

  @MainActor func handleDoneAction() {}

  @MainActor
  func onEditToggleSelectTapped() {
    withAnimation {
      editMode = editMode.isEditing ? .inactive : .active
    }
    if !editMode.isEditing { selectedItems.removeAll() }
  }

  @MainActor
  func onSelectTapped(for item: JellyfinLibraryItem) {
    guard item.isDownloadable else { return }
    if selectedItems.contains(item.id) {
      selectedItems.remove(item.id)
    } else {
      selectedItems.insert(item.id)
    }
  }

  @MainActor
  func onSelectAllTapped() {
    if selectedItems.isEmpty {
      selectedItems = Set(items.compactMap { $0.isDownloadable ? $0.id : nil })
    } else {
      selectedItems.removeAll()
    }
  }

  @MainActor
  func onDownloadTapped() {
    let downloadItems = selectedItems.compactMap { id in
      items.first(where: { $0.id == id && $0.isDownloadable })
    }
    guard !downloadItems.isEmpty else { return }
    var requests = [URLRequest]()
    for item in downloadItems {
      do {
        let request = try connectionService.createItemDownloadRequest(item)
        requests.append(request)
      } catch {
        self.error = error
      }
    }
    guard !requests.isEmpty else { return }
    singleFileDownloadService.handleDownload(requests)
    navigation.dismiss?()
  }

  @MainActor func onDownloadFolderTapped() {}
  @MainActor func confirmDownloadFolder() {}

  private func applySearch() {
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    if query.isEmpty {
      items = allItems
    } else {
      items = allItems.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    totalItems = items.count
  }
}

// MARK: - Authors List ViewModel

@MainActor
final class JellyfinAuthorsListViewModel: IntegrationLibraryViewModelProtocol, BPLogger {
  let parentID: String?

  var navigation: BPNavigation
  let navigationTitle: String

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayout)
  var layout: IntegrationLayout.Options = .list

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayoutSortBy)
  var sortBy: JellyfinLayout.SortBy = .name

  @Published var searchQuery = ""
  @Published var items: [JellyfinLibraryItem] = []
  @Published var totalItems = Int.max
  @Published var error: Error?

  @Published var editMode: EditMode = .inactive
  @Published var selectedItems: Set<JellyfinLibraryItem.ID> = []
  @Published var showingDownloadConfirmation = false

  var isSearchable: Bool { true }

  let connectionService: JellyfinConnectionService
  var importManager: ImportManager?
  let accountService: AccountService
  private let singleFileDownloadService: SingleFileDownloadService
  private var fetchTask: Task<(), any Error>?
  private var allItems: [JellyfinLibraryItem] = []
  private var disposeBag = Set<AnyCancellable>()

  init(
    parentID: String?,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    importManager: ImportManager?,
    accountService: AccountService,
    navigation: BPNavigation,
    navigationTitle: String
  ) {
    self.parentID = parentID
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.importManager = importManager
    self.accountService = accountService
    self.navigation = navigation
    self.navigationTitle = navigationTitle

    $searchQuery
      .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
      .removeDuplicates()
      .dropFirst()
      .sink { [weak self] _ in self?.applyLocalSearch() }
      .store(in: &disposeBag)
  }

  func fetchInitialItems() {
    guard items.isEmpty, fetchTask == nil else { return }
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }
      do {
        let (items, _) = try await connectionService.fetchAlbumArtists(parentID: parentID)
        self.allItems = items
        applyLocalSearch()
      } catch is CancellationError {
      } catch {
        self.error = error
      }
    }
  }

  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem) {}
  func cancelFetchItems() { fetchTask?.cancel(); fetchTask = nil }

  func destination(for item: JellyfinLibraryItem) -> JellyfinLibraryLevelData? {
    guard item.kind == .author else { return nil }
    return .authorBooks(authorID: item.id, authorName: item.name, parentID: parentID)
  }

  @MainActor func handleDoneAction() {}
  @MainActor func onEditToggleSelectTapped() {}
  @MainActor func onSelectTapped(for item: JellyfinLibraryItem) {}
  @MainActor func onSelectAllTapped() {}
  @MainActor func onDownloadTapped() {}
  @MainActor func onDownloadFolderTapped() {}
  @MainActor func confirmDownloadFolder() {}

  private func applyLocalSearch() {
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    items = query.isEmpty ? allItems : allItems.filter { $0.name.localizedCaseInsensitiveContains(query) }
    totalItems = items.count
  }
}

// MARK: - Narrators List ViewModel

@MainActor
final class JellyfinNarratorsListViewModel: IntegrationLibraryViewModelProtocol, BPLogger {
  let parentID: String?

  var navigation: BPNavigation
  let navigationTitle: String

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayout)
  var layout: IntegrationLayout.Options = .list

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayoutSortBy)
  var sortBy: JellyfinLayout.SortBy = .name

  @Published var searchQuery = ""
  @Published var items: [JellyfinLibraryItem] = []
  @Published var totalItems = Int.max
  @Published var error: Error?

  @Published var editMode: EditMode = .inactive
  @Published var selectedItems: Set<JellyfinLibraryItem.ID> = []
  @Published var showingDownloadConfirmation = false

  var isSearchable: Bool { true }

  let connectionService: JellyfinConnectionService
  var importManager: ImportManager?
  let accountService: AccountService
  private let singleFileDownloadService: SingleFileDownloadService
  private var fetchTask: Task<(), any Error>?
  private var allItems: [JellyfinLibraryItem] = []
  private var disposeBag = Set<AnyCancellable>()

  init(
    parentID: String?,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    importManager: ImportManager?,
    accountService: AccountService,
    navigation: BPNavigation,
    navigationTitle: String
  ) {
    self.parentID = parentID
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.importManager = importManager
    self.accountService = accountService
    self.navigation = navigation
    self.navigationTitle = navigationTitle

    $searchQuery
      .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
      .removeDuplicates()
      .dropFirst()
      .sink { [weak self] _ in self?.applyLocalSearch() }
      .store(in: &disposeBag)
  }

  func fetchInitialItems() {
    guard items.isEmpty, fetchTask == nil else { return }
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }
      do {
        let (items, _) = try await connectionService.fetchNarrators(parentID: parentID)
        self.allItems = items
        applyLocalSearch()
      } catch is CancellationError {
      } catch {
        self.error = error
      }
    }
  }

  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem) {}
  func cancelFetchItems() { fetchTask?.cancel(); fetchTask = nil }

  func destination(for item: JellyfinLibraryItem) -> JellyfinLibraryLevelData? {
    guard item.kind == .narrator else { return nil }
    return .narratorBooks(personID: item.id, personName: item.name, parentID: parentID)
  }

  @MainActor func handleDoneAction() {}
  @MainActor func onEditToggleSelectTapped() {}
  @MainActor func onSelectTapped(for item: JellyfinLibraryItem) {}
  @MainActor func onSelectAllTapped() {}
  @MainActor func onDownloadTapped() {}
  @MainActor func onDownloadFolderTapped() {}
  @MainActor func confirmDownloadFolder() {}

  private func applyLocalSearch() {
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    items = query.isEmpty ? allItems : allItems.filter { $0.name.localizedCaseInsensitiveContains(query) }
    totalItems = items.count
  }
}
