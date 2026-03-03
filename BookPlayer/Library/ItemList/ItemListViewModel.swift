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
  /// Stores item identifiers from import operations to avoid race condition
  /// where items may not be loaded in the UI yet when moving to a folder
  var pendingMoveItemIdentifiers: [String]?

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

  func loadNextPage(_ pageSize: Int? = 13) async {
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
  
  func syncUuids() async {
    await syncService.scheduleMatchUuid(params: [:])
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
      if canLoadMore {
        await loadNextPage(nil)
      }
      selectedSetItems = Set(items.map { $0.id })
    }
  }

  func handleSort(by option: SortType) {
    libraryService.sortContents(at: libraryNode.folderRelativePath, by: option)
    reloadItems()
  }

  func getNextPlayableBookPath(in item: SimpleLibraryItem) -> String? {
    guard item.type == .folder else { return nil }

    /// If the player already is playing a subset of this folder, let the player handle playback
    if let currentItem = playerManager.currentItem,
       currentItem.relativePath.contains(item.relativePath) {
      return currentItem.relativePath
    }

    let nextPlayableItem = try? playbackService.getFirstPlayableItem(
      in: item,
      isUnfinished: true
    )

    return nextPlayableItem?.relativePath
  }
}

// MARK: - 'More' actions handlers
extension ItemListViewModel {
  func handleResetPlaybackPosition() {
    let currentlyPlayingPath = playerManager.currentItem?.relativePath

    for selectedItem in selectedItems {
      libraryService.jumpToStart(relativePath: selectedItem.relativePath)

      if currentlyPlayingPath == selectedItem.relativePath {
        playerManager.pause()
        playerManager.jumpTo(0, recordBookmark: false)
      }
    }

    if let parentFolder = libraryNode.folderRelativePath {
      libraryService.recursiveFolderProgressUpdate(from: parentFolder)
    }

    listState.reloadAll()
    editMode = .inactive
  }

  func handleMarkAsFinished(flag: Bool) {
    selectedItems.forEach {
      libraryService.markAsFinished(flag: flag, relativePath: $0.relativePath)
    }

    if let parentFolder = libraryNode.folderRelativePath {
      libraryService.recursiveFolderProgressUpdate(from: parentFolder)
    }

    listState.reloadAll()
    editMode = .inactive
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
      editMode = .inactive
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
    editMode = .inactive
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
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
          return
        }
        
        let folder = try libraryService.createFolder(
          with: trimmedTitle,
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
        editMode = .inactive
      } catch {
        loadingState.error = error
      }
    }
  }

  func handleMoveIntoFolder(_ folder: SimpleLibraryItem) {
    // Use pendingMoveItemIdentifiers if available (from import operations),
    // otherwise fall back to selectedItems (from manual selection)
    let fetchedItems: [String]
    if let pendingItems = pendingMoveItemIdentifiers {
      fetchedItems = pendingItems
      pendingMoveItemIdentifiers = nil
    } else {
      fetchedItems = selectedItems.compactMap({ $0.relativePath })
    }

    do {
      try libraryService.moveItems(fetchedItems, inside: folder.relativePath)
      syncService.scheduleMove(items: fetchedItems, to: folder.relativePath)
    } catch {
      loadingState.error = error
    }

    listState.reloadAll()
    editMode = .inactive
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
    editMode = .inactive
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

  /// Returns destination URLs of files that already exist and were not copied.
  func handleFilePickerSelection(_ urls: [URL]) -> [URL] {
    let documentsFolder = DataManager.getDocumentsFolderURL()

    // Acquire security-scoped access synchronously before URLs expire
    var filesToCopy: [(source: URL, destination: URL)] = []
    var alreadyExisting: [URL] = []
    var skippedOwnFiles = 0
    for url in urls {
      let gotAccess = url.startAccessingSecurityScopedResource()
      guard gotAccess else { continue }

      if DataManager.isAppOwnFolder(url) {
        skippedOwnFiles += 1
        url.stopAccessingSecurityScopedResource()
        continue
      }

      let destinationURL = documentsFolder.appendingPathComponent(url.lastPathComponent)
      if !FileManager.default.fileExists(atPath: destinationURL.path) {
        filesToCopy.append((source: url, destination: destinationURL))
      } else {
        alreadyExisting.append(destinationURL)
        url.stopAccessingSecurityScopedResource()
      }
    }

    guard !filesToCopy.isEmpty else {
      if skippedOwnFiles > 0 {
        loadingState.error = BookPlayerError.runtimeError(
          NSLocalizedString("import_already_loaded_title", comment: "")
        )
      }
      return alreadyExisting
    }

    // Check if any files need downloading from the cloud
    let pendingDownload = filesToCopy.reduce(
      into: (count: 0, totalSize: Int64(0))
    ) { result, file in
      let info = notDownloadedContentInfo(file.source)
      result.count += info.count
      result.totalSize += info.totalSize
    }

    if pendingDownload.count > 0 {
      let sizeString = ByteCountFormatter.string(
        fromByteCount: pendingDownload.totalSize,
        countStyle: .file
      )
      loadingState.message = String(
        format: NSLocalizedString("import_preparing_detail_title", comment: ""),
        pendingDownload.count,
        sizeString
      )
        + "\n"
        + NSLocalizedString("import_keep_app_open_title", comment: "")
      loadingState.show = true

      // Yield the main thread so SwiftUI renders the overlay before the blocking copy
      DispatchQueue.main.async {
        self.performFileCopy(filesToCopy)
      }
    } else {
      performFileCopy(filesToCopy)
    }

    return alreadyExisting
  }

  private func performFileCopy(_ filesToCopy: [(source: URL, destination: URL)]) {
    for file in filesToCopy {
      do {
        try FileManager.default.copyItem(at: file.source, to: file.destination)
      } catch {
        loadingState.error = error
      }
      file.source.stopAccessingSecurityScopedResource()
    }

    loadingState.show = false
    loadingState.message = nil
  }

  /// Returns the count and total size of not-yet-downloaded cloud content for a URL.
  private nonisolated func notDownloadedContentInfo(
    _ url: URL
  ) -> (count: Int, totalSize: Int64) {
    let keys: Set<URLResourceKey> = [
      .isDirectoryKey,
      .ubiquitousItemDownloadingStatusKey,
      .totalFileSizeKey,
    ]

    guard let values = try? url.resourceValues(forKeys: keys) else {
      return (0, 0)
    }

    let isNotDownloaded = values.ubiquitousItemDownloadingStatus?.rawValue
      == URLUbiquitousItemDownloadingStatus.notDownloaded.rawValue
    let isDirectory = values.isDirectory ?? false

    if !isDirectory {
      if isNotDownloaded {
        return (1, Int64(values.totalFileSize ?? 0))
      }
      return (0, 0)
    }

    // For directories, enumerate children
    guard let enumerator = FileManager.default.enumerator(
      at: url,
      includingPropertiesForKeys: Array(keys),
      options: [.skipsHiddenFiles]
    ) else { return (0, 0) }

    var count = 0
    var totalSize: Int64 = 0

    for case let fileURL as URL in enumerator {
      let childValues = try? fileURL.resourceValues(forKeys: keys)
      if childValues?.ubiquitousItemDownloadingStatus?.rawValue
        == URLUbiquitousItemDownloadingStatus.notDownloaded.rawValue
      {
        count += 1
        totalSize += Int64(childValues?.totalFileSize ?? 0)
      }
    }

    return (count, totalSize)
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
