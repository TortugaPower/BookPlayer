//
//  ItemListViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 18/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

@MainActor
final class ItemListViewModel: ObservableObject {
  let libraryNode: LibraryNode
  private let libraryService: LibraryService
  private let playbackService: PlaybackService
  let playerManager: PlayerManager
  private let syncService: SyncService
  private let listSyncRefreshService: ListSyncRefreshService
  private let loadingState: LoadingOverlayState
  private let listState: ListStateManager
  let singleFileDownloadService: SingleFileDownloadService

  /// Reference to ongoing library fetch task
  var contentsFetchTask: Task<(), Error>?

  @Published var items: [SimpleLibraryItem] = []
  @Published var isLoading: Bool = false
  @Published var canLoadMore: Bool = true

  private var offset = 0

  var reloadScope: ListStateManager.Scope {
    switch libraryNode {
    case .root: return .path("")
    case .book(_, let relativePath), .folder(_, let relativePath):
      return .path(relativePath)
    }
  }

  var filteredResults: [SimpleLibraryItem] {
    var filteredItems = items

    switch scope {
    case .books: filteredItems.removeAll { $0.type == .folder }
    case .folders: filteredItems.removeAll { $0.type != .folder }
    case .all: break
    }

    if !query.isEmpty {
      filteredItems = filteredItems.filter {
        $0.title.localizedCaseInsensitiveContains(query) || $0.details.localizedCaseInsensitiveContains(query)
      }
    }
    return filteredItems
  }

  var isListEmpty: Bool {
    items.isEmpty && !canLoadMore
  }

  var navigationTitle: String {
    libraryNode.title
  }

  @Published var editMode: EditMode = .inactive {
    didSet {
      listState.isEditing = editMode.isEditing
      if editMode.isEditing {
        isSearchFocused = false
      }
    }
  }
  @Published var selectedSetItems = Set<SimpleLibraryItem.ID>() {
    didSet {
      selectedItems = items.filter { selectedSetItems.contains($0.id) }
    }
  }
  @Published var selectedItems = [SimpleLibraryItem]()

  /// Search
  @Published var scope: ItemListSearchScope = .all
  @Published var query = ""
  @Published var isSearchFocused: Bool = false {
    didSet {
      listState.isSearching = isSearchFocused
      if isSearchFocused {
        editMode = .inactive
      }
    }
  }

  init(
    libraryNode: LibraryNode,
    libraryService: LibraryService,
    playbackService: PlaybackService,
    playerManager: PlayerManager,
    syncService: SyncService,
    listSyncRefreshService: ListSyncRefreshService,
    loadingState: LoadingOverlayState,
    listState: ListStateManager,
    singleFileDownloadService: SingleFileDownloadService
  ) {
    self.libraryNode = libraryNode
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.playerManager = playerManager
    self.syncService = syncService
    self.listSyncRefreshService = listSyncRefreshService
    self.loadingState = loadingState
    self.listState = listState
    self.singleFileDownloadService = singleFileDownloadService

    if libraryNode == .root {
      playerManager.syncProgressDelegate = self
    }
  }

  // MARK: - Infinite list

  func loadNextPage(_ pageSize: Int? = 4) async {
    guard !isLoading, canLoadMore else { return }

    isLoading = true

    let fetchedItems =
      libraryService.fetchContents(
        at: libraryNode.folderRelativePath,
        limit: pageSize,
        offset: offset
      ) ?? []

    items += fetchedItems
    offset = items.count

    canLoadMore = fetchedItems.count == pageSize
    isLoading = false
  }

  @MainActor
  func reloadItems(with pageSizePadding: Int = 0) {
    let pageSize = self.items.count + pageSizePadding

    isLoading = true

    let fetchedItems =
      libraryService.fetchContents(
        at: libraryNode.folderRelativePath,
        limit: pageSize,
        offset: 0
      ) ?? []

    items = fetchedItems
    offset = items.count

    canLoadMore = fetchedItems.count == pageSize
    isLoading = false
  }

  func prefetchIfNeeded(for item: SimpleLibraryItem) async {
    guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }

    let threshold = max(items.count - 5, 0)

    if idx >= threshold {
      await loadNextPage()
    }
  }

  func processFoldersStaleProgress() -> Bool {
    guard libraryNode == .root else { return false }

    /// Process any deferred progress calculations for folders
    return playbackService.processFoldersStaleProgress()
  }

  func syncList() async {
    if processFoldersStaleProgress() {
      listState.reloadAll()
    }

    /// check if it's called from both on first appear and from scene delegate
    guard
      await syncService.canSyncListContents(
        at: libraryNode.folderRelativePath,
        ignoreLastTimestamp: false
      )
    else { return }

    /// Create new task to sync the library and the last played
    await MainActor.run {
      contentsFetchTask?.cancel()
      contentsFetchTask = Task {
        do {
          try await listSyncRefreshService.syncList(at: libraryNode.folderRelativePath)
          await MainActor.run {
            listState.reloadAll()
          }
        } catch {
          loadingState.error = error
        }
      }
    }
  }

  func refreshListState() async throws {
    guard syncService.isActive else { return }

    guard await syncService.queuedJobsCount() == 0 else {
      throw BPSyncRefreshError.scheduledTasks
    }

    do {
      try await listSyncRefreshService.syncList(at: libraryNode.folderRelativePath)
      await MainActor.run {
        listState.reloadAll()
      }
    } catch {
      loadingState.error = error
    }
  }

  func getPathForParentOfPlayingItem(_ path: String?) -> String? {
    guard let path else { return nil }

    let parentFolders: [String] = path.allRanges(of: "/")
      .map { String(path.prefix(upTo: $0.lowerBound)) }
      .reversed()

    guard case .folder(_, let folderRelativePath) = libraryNode else {
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

  func reorderItems(
    source: IndexSet,
    destination: Int
  ) {
    libraryService.reorderItems(
      inside: libraryNode.folderRelativePath,
      fromOffsets: source,
      toOffset: destination
    )

    reloadItems()
  }

  func handleSelectAll() {
    Task {
      await loadNextPage(nil)
      selectedSetItems = Set(items.map { $0.id })
    }
  }

  func handleSort(by option: SortType) {
    libraryService.sortContents(at: libraryNode.folderRelativePath, by: option)
    reloadItems()
  }
}

// MARK: - 'More' actions handlers
extension ItemListViewModel {
  func handleResetPlaybackPosition() {
    selectedItems.forEach({ libraryService.jumpToStart(relativePath: $0.relativePath) })

    listState.reloadAll()
  }

  func handleMarkAsFinished(flag: Bool) {
    let parentFolder = selectedItems.first?.parentFolder

    selectedItems.forEach {
      libraryService.markAsFinished(flag: flag, relativePath: $0.relativePath)
    }

    if let parentFolder {
      libraryService.rebuildFolderDetails(parentFolder)
    }

    listState.reloadAll()
  }

  func updateFolders(_ folders: [SimpleLibraryItem], type: SimpleItemType) {
    do {
      try folders.forEach { folder in
        try libraryService.updateFolder(at: folder.relativePath, type: type)

        if let currentItem = playerManager.currentItem,
          currentItem.relativePath.contains(folder.relativePath)
        {
          playerManager.stop()
        }
      }

      listState.reloadAll()
    } catch {
      loadingState.error = error
    }
  }

  func handleMoveIntoLibrary() {
    let selectedItemPaths = selectedItems.compactMap({ $0.relativePath })
    let parentFolder = selectedItems.first?.parentFolder

    do {
      try libraryService.moveItems(selectedItemPaths, inside: nil)
      syncService.scheduleMove(items: selectedItemPaths, to: nil)
      if let parentFolder {
        libraryService.rebuildFolderDetails(parentFolder)
      }
    } catch {
      loadingState.error = error
    }

    listState.reloadAll(padding: selectedItems.count)
  }

  func importIntoLibrary(_ items: [String]) {
    do {
      try libraryService.moveItems(items, inside: nil)
      syncService.scheduleMove(items: items, to: nil)
    } catch {
      loadingState.error = error
    }

    listState.reloadAll(padding: items.count)
  }

  func createFolder(with title: String, items: [String]? = nil, type: SimpleItemType) {
    Task { @MainActor in
      do {
        let folder = try libraryService.createFolder(
          with: title,
          inside: libraryNode.folderRelativePath
        )
        await syncService.scheduleUpload(items: [folder])
        if let fetchedItems = items {
          try libraryService.moveItems(fetchedItems, inside: folder.relativePath)
          syncService.scheduleMove(items: fetchedItems, to: folder.relativePath)
        }
        try libraryService.updateFolder(at: folder.relativePath, type: type)
        libraryService.rebuildFolderDetails(folder.relativePath)

        // stop playback if folder items contain that current item
        if let items = items,
          let currentRelativePath = playerManager.currentItem?.relativePath,
          items.contains(currentRelativePath)
        {
          playerManager.stop()
        }

        listState.reloadAll(padding: 1)
      } catch {
        loadingState.error = error
      }
    }
  }

  func handleMoveIntoFolder(_ folder: SimpleLibraryItem) {
    let fetchedItems = selectedItems.compactMap({ $0.relativePath })

    do {
      try libraryService.moveItems(fetchedItems, inside: folder.relativePath)
      syncService.scheduleMove(items: fetchedItems, to: folder.relativePath)
    } catch {
      loadingState.error = error
    }

    listState.reloadAll()
  }

  func handleDelete(items: [SimpleLibraryItem], mode: DeleteMode) {
    if mode == .deep,
       items.contains(where: { $0.relativePath == playerManager.currentItem?.relativePath }) {
      playerManager.stop()
    }

    let parentFolder = items.first?.parentFolder

    do {
      try libraryService.delete(items, mode: mode)

      if let parentFolder {
        libraryService.rebuildFolderDetails(parentFolder)
      }

      syncService.scheduleDelete(items, mode: mode)
    } catch {
      loadingState.error = error
    }

    listState.reloadAll()
  }

  func deleteActionDetails() -> (title: String, message: String?)? {
    guard !selectedItems.isEmpty else { return nil }

    var title: String
    var message: String?

    if selectedItems.count == 1,
      let item = selectedItems.first
    {
      title = String(format: "delete_single_item_title".localized, item.title)
      message = item.type == .folder ? "delete_single_playlist_description".localized : nil
    } else {
      title = String.localizedStringWithFormat("delete_multiple_items_title".localized, selectedItems.count)
      message = "delete_multiple_items_description".localized
    }

    return (title, message)
  }

  func getAvailableFolders() -> [SimpleLibraryItem] {
    let items = selectedItems
    var availableFolders = [SimpleLibraryItem]()

    guard
      let existingItems = libraryService.fetchContents(
        at: libraryNode.folderRelativePath,
        limit: nil,
        offset: nil
      )
    else { return [] }

    let existingFolders = existingItems.filter({ $0.type == .folder })

    for folder in existingFolders {
      if items.contains(where: { $0.relativePath == folder.relativePath }) { continue }

      availableFolders.append(folder)
    }

    return availableFolders
  }

  func handleFilePickerSelection(_ urls: [URL]) {
    let documentsFolder = DataManager.getDocumentsFolderURL()
    urls.forEach { url in
      let gotAccess = url.startAccessingSecurityScopedResource()
      if !gotAccess { return }

      let destinationURL = documentsFolder.appendingPathComponent(url.lastPathComponent)
      if !FileManager.default.fileExists(atPath: destinationURL.path) {
        try! FileManager.default.copyItem(at: url, to: destinationURL)
      }

      url.stopAccessingSecurityScopedResource()
    }
  }
}

// MARK: - Network related handlers
extension ItemListViewModel {
  func startDownload(of item: SimpleLibraryItem) {
    Task { @MainActor in
      loadingState.show = true

      do {
        let fileURL = item.fileURL
        /// Create backing folder if it does not exist
        if item.type == .folder || item.type == .bound {
          try DataManager.createBackingFolderIfNeeded(fileURL)
        }

        try await syncService.downloadRemoteFiles(for: item)
        loadingState.show = false
      } catch {
        loadingState.show = false
        loadingState.error = error
      }
    }
  }

  func cancelDownload(of item: SimpleLibraryItem) {
    do {
      try syncService.cancelDownload(of: item)
    } catch {
      loadingState.error = error
    }
  }

  func handleOffloading(of item: SimpleLibraryItem) {
    do {
      let fileURL = item.fileURL
      try FileManager.default.removeItem(at: fileURL)
      if item.type == .bound || item.type == .folder {
        try FileManager.default.createDirectory(
          at: fileURL,
          withIntermediateDirectories: false,
          attributes: nil
        )
      }

      ArtworkService.artworkUpdatePublisher.send(item.relativePath)
    } catch {
      loadingState.error = error
    }
  }

  func downloadFromURL(_ string: String) {
    do {
      let url = try getDownloadURL(for: string)
      singleFileDownloadService.handleDownload(url)
    } catch {
      loadingState.error = error
    }
  }

  private func getDownloadURL(for givenString: String) throws -> URL {
    guard
      let givenUrl = URL(string: givenString),
      let hostname = givenUrl.host
    else {
      throw String.localizedStringWithFormat("invalid_url_title".localized, givenString)
    }
    switch hostname {
    case "drive.google.com":
      return getGoogleDriveURL(for: givenUrl)
    case "dropbox.com", "www.dropbox.com":
      return try getDropboxURL(for: givenUrl)
    default:
      return givenUrl
    }
  }

  private func getGoogleDriveURL(for url: URL) -> URL {
    let pathComponents = url.pathComponents
    guard
      let index = pathComponents.firstIndex(of: "d"),
      index + 1 < pathComponents.count,
      let newUrl = URL(string: "https://drive.google.com/uc?export=download&id=" + pathComponents[index + 1])
    else {
      return url
    }
    return newUrl
  }

  private func getDropboxURL(for url: URL) throws -> URL {
    guard
      var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
      throw String.localizedStringWithFormat("invalid_url_title".localized, url.absoluteString)
    }
    var queryItems = urlComponents.queryItems ?? []
    if let index = queryItems.firstIndex(where: { $0.name == "dl" }) {
      queryItems[index].value = "1"
    } else {
      queryItems.append(URLQueryItem(name: "dl", value: "1"))
    }
    urlComponents.queryItems = queryItems
    return urlComponents.url ?? url
  }

  func handleSingleFileDownloadError(
    _ errorKind: SingleFileDownloadService.ErrorKind,
    task: URLSessionTask,
    underlyingError: Error?
  ) {
    switch errorKind {

    case .general:
      loadingState.error = underlyingError
    case .network:
      if let underlyingError {
        loadingState.error = underlyingError
        return
      }

      guard let statusCode = (task.response as? HTTPURLResponse)?.statusCode,
            statusCode >= 400 else {
        return
      }

      loadingState.error = BookPlayerError.networkError("Code \(statusCode)\n\(HTTPURLResponse.localizedString(forStatusCode: statusCode))")
    }
  }
}

extension ItemListViewModel: PlaybackSyncProgressDelegate {
  func waitForSyncInProgress() async {
    _ = await contentsFetchTask?.result
  }
}
