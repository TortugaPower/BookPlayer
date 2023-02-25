//
//  ItemListViewModel.swift
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

class ItemListViewModel: BaseViewModel<ItemListCoordinator> {
  /// Available routes for this screen
  enum Routes {
    case showFolder(relativePath: String)
    case loadPlayer(relativePath: String)
    case showDocumentPicker
    case showCreateFolderAlert(placeholder: String?, items: [String]?, type: SimpleItemType)
    case showSearchList(relativePath: String?, placeholderTitle: String)
  }

  enum Events {
    case newData
    case reloadIndex(_ indexPath: IndexPath)
    case downloadState(_ state: DownloadState, indexPath: IndexPath)
    case showAlert(content: BPAlertContent)
    case showActionSheet(content: BPSheetContent)
    case showLoader(flag: Bool)
  }

  let folderRelativePath: String?
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let syncService: SyncServiceProtocol
  var offset = 0

  public private(set) var defaultArtwork: Data?
  public private(set) var items = [SimpleLibraryItem]()

  var eventsPublisher = InterfaceUpdater<ItemListViewModel.Events>()

  private var bookProgressSubscription: AnyCancellable?
  private var downloadDelegateInterface = BPTaskDownloadDelegate()
  /// Dictionary holding the starting item relative path as key and the download tasks as value
  private lazy var downloadTasksDictionary = [String: [URLSessionDownloadTask]]()
  /// Reference to the starting item path for the download tasks (relevant for bound books)
  private lazy var ongoingTasksParentReference = [String: String]()
  /// Callback to handle actions on this screen
  public var onTransition: Transition<Routes>?

  private var disposeBag = Set<AnyCancellable>()
  /// Cached path for containing folder of playing item in relation to this list path
  private var playingItemParentPath: String?

  public var maxItems: Int {
    return self.libraryService.getMaxItemsCount(at: self.folderRelativePath)
  }

  /// Initializer
  init(
    folderRelativePath: String?,
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol,
    themeAccent: UIColor
  ) {
    self.folderRelativePath = folderRelativePath
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.syncService = syncService
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: themeAccent)?.pngData()
    super.init()

    self.bindObservers()
  }

  func getEmptyStateImageName() -> String {
    return self.coordinator is LibraryListCoordinator
    ? "emptyLibrary"
    : "emptyPlaylist"
  }

  func getNavigationTitle() -> String {
    guard let folderRelativePath = folderRelativePath else {
      return "library_title".localized
    }

    guard let item = self.libraryService.getItem(with: folderRelativePath) else {
      return ""
    }

    return item.title
  }

  func observeEvents() -> AnyPublisher<ItemListViewModel.Events, Never> {
    eventsPublisher.eraseToAnyPublisher()
  }

  func bindObservers() {
    bindBookObservers()
    bindDownloadObservers()
  }

  func bindBookObservers() {
    self.playerManager.currentItemPublisher()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] currentItem in
      guard let self = self else { return }

      self.bookProgressSubscription?.cancel()

      defer {
        self.clearPlaybackState()
      }

      guard let currentItem = currentItem else {
        self.playingItemParentPath = nil
        return
      }

      self.playingItemParentPath = self.getPathForParentOfItem(currentItem: currentItem)

      self.bindItemProgressObserver(currentItem)
    }.store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .folderProgressUpdated)
      .sink { [weak self] notification in
        guard
          let playingItemParentPath = self?.playingItemParentPath,
          let relativePath = notification.userInfo?["relativePath"] as? String,
          playingItemParentPath == relativePath,
          let index = self?.items.firstIndex(where: { relativePath == $0.relativePath }),
          let progress = notification.userInfo?["progress"] as? Double
        else {
          return
        }

        self?.items[index].percentCompleted = progress

        let indexModified = IndexPath(row: index, section: BPSection.data.rawValue)
        self?.sendEvent(.reloadIndex(indexModified))
      }.store(in: &disposeBag)
  }

  func bindDownloadObservers() {
    downloadDelegateInterface.didFinishDownloadingTask = { [weak self] (task, location) in
      self?.handleFinishedDownload(task: task, location: location)
    }

    downloadDelegateInterface.downloadProgressUpdated = { [weak self] (task, progress) in
      self?.handleDownloadProgressUpdated(task: task, individualProgress: progress)
    }
  }

  func getPathForParentOfItem(currentItem: PlayableItem) -> String? {
    let parentFolders: [String] = currentItem.relativePath.allRanges(of: "/")
      .map { String(currentItem.relativePath.prefix(upTo: $0.lowerBound)) }
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

  func bindItemProgressObserver(_ item: PlayableItem) {
    self.bookProgressSubscription?.cancel()
    self.bookProgressSubscription = item.publisher(for: \.percentCompleted)
      .combineLatest(item.publisher(for: \.relativePath))
      .removeDuplicates(by: { $0.0 == $1.0 })
      .sink(receiveValue: { [weak self] (percentCompleted, relativePath) in
        /// Check if item is in this list, otherwise do not process progress update
        guard
          let self = self,
          item.parentFolder == self.folderRelativePath,
          let index = self.items.firstIndex(where: { relativePath == $0.relativePath })
        else { return }

        self.items[index].percentCompleted = percentCompleted

        let indexModified = IndexPath(row: index, section: BPSection.data.rawValue)
        self.sendEvent(.reloadIndex(indexModified))
      })
  }

  func clearPlaybackState() {
    sendEvent(.newData)
  }

  func loadInitialItems(pageSize: Int = 13) {
    guard
      let fetchedItems = self.libraryService.fetchContents(
        at: self.folderRelativePath,
        limit: pageSize,
        offset: 0
      )
    else { return }

    self.offset = fetchedItems.count
    self.items = fetchedItems
  }

  func loadNextItems(pageSize: Int = 13) {
    guard self.offset < self.maxItems else { return }

    guard
      let fetchedItems = self.libraryService.fetchContents(
        at: self.folderRelativePath,
        limit: pageSize,
        offset: self.offset
      ),
      !fetchedItems.isEmpty
    else {
      return
    }

    self.offset += fetchedItems.count

    self.items += fetchedItems
    sendEvent(.newData)
  }

  func loadAllItemsIfNeeded() {
    guard self.offset < self.maxItems else { return }

    guard
      let fetchedItems = self.libraryService.fetchContents(
        at: self.folderRelativePath,
        limit: self.maxItems,
        offset: 0
      ),
      !fetchedItems.isEmpty
    else {
      return
    }

    self.offset = fetchedItems.count
    self.items = fetchedItems
    sendEvent(.newData)
  }

  func getItem(of type: SimpleItemType, after currentIndex: Int) -> Int? {
    guard let (index, _) = (self.items.enumerated().first { (index, item) in
      guard index > currentIndex else { return false }

      return item.type == type
    }) else { return nil }

    return index
  }

  func getItem(of type: SimpleItemType, before currentIndex: Int) -> Int? {
    guard let (index, _) = (self.items.enumerated().reversed().first { (index, item) in
      guard index < currentIndex else { return false }

      return item.type == type
    }) else { return nil }

    return index
  }

  private func playNextBook(in item: SimpleLibraryItem) {
    guard item.type == .folder else { return }

    /// If the player already is playing a subset of this folder, let the player handle playback
    if let currentItem = self.playerManager.currentItem,
       currentItem.relativePath.contains(item.relativePath) {
      self.playerManager.play()
    } else if
      let folder = self.libraryService.getItem(with: item.relativePath) as? Folder,
      let nextPlayableItem = try? self.playbackService.getFirstPlayableItem(
        in: folder,
        isUnfinished: true
      ),
      let nextItem = libraryService.fetchContents(at: nextPlayableItem.relativePath, limit: 1, offset: nil)?.first {

      showItemContents(nextItem)
    }
  }

  func handleArtworkTap(for item: SimpleLibraryItem) {
    switch item.type {
    case .folder:
      playNextBook(in: item)
    case .bound, .book:
      switch getDownloadState(for: item) {
      case .notDownloaded:
        startDownload(of: item)
      case .downloading:
        cancelDownload(of: item)
      case .downloaded:
        onTransition?(.loadPlayer(relativePath: item.relativePath))
      }
    }
  }

  func reloadItems(pageSizePadding: Int = 0) {
    let pageSize = self.items.count + pageSizePadding
    self.loadInitialItems(pageSize: pageSize)
    sendEvent(.newData)
  }

  func getPlaybackState(for item: SimpleLibraryItem) -> PlaybackState {
    guard let currentItem = self.playerManager.currentItem else {
      return .stopped
    }

    if item.relativePath == currentItem.relativePath {
      return .playing
    }

    return item.relativePath == playingItemParentPath ? .playing : .stopped
  }

  func showItemContents(_ item: SimpleLibraryItem) {
    switch item.type {
    case .folder:
      onTransition?(.showFolder(relativePath: item.relativePath))
    case .book, .bound:
      switch getDownloadState(for: item) {
      case .downloading:
        cancelDownload(of: item)
      case .downloaded, .notDownloaded:
        onTransition?(.loadPlayer(relativePath: item.relativePath))
      }
    }
  }

  func importIntoFolder(_ folder: SimpleLibraryItem, items: [LibraryItem], type: SimpleItemType) {
    let fetchedItems = items.compactMap({ self.libraryService.getItem(with: $0.relativePath )})

    do {
      try self.libraryService.moveItems(fetchedItems, inside: folder.relativePath, moveFiles: true)
      try self.libraryService.updateFolder(at: folder.relativePath, type: type)

      libraryService.rebuildFolderDetails(folder.relativePath)
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent(title: "error_title".localized, message: error.localizedDescription))
      )
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func createFolder(with title: String, items: [String]? = nil, type: SimpleItemType) {
    do {
      let folder = try self.libraryService.createFolder(with: title, inside: self.folderRelativePath)
      if let fetchedItems = items?.compactMap({ self.libraryService.getItem(with: $0 )}) {
        try self.libraryService.moveItems(fetchedItems, inside: folder.relativePath, moveFiles: true)
      }
      try self.libraryService.updateFolder(at: folder.relativePath, type: type)
      libraryService.rebuildFolderDetails(folder.relativePath)

      // stop playback if folder items contain that current item
      if let items = items,
         let currentRelativePath = self.playerManager.currentItem?.relativePath,
         items.contains(currentRelativePath) {
        self.playerManager.stop()
      }

    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent(title: "error_title".localized, message: error.localizedDescription))
      )
    }

    self.coordinator.reloadItemsWithPadding(padding: 1)
  }

  func updateFolders(_ folders: [SimpleLibraryItem], type: SimpleItemType) {
    do {
      try folders.forEach { folder in
        try self.libraryService.updateFolder(at: folder.relativePath, type: type)

        if let currentItem = self.playerManager.currentItem,
           currentItem.relativePath.contains(folder.relativePath) {
          self.playerManager.stop()
        }
      }
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent(title: "error_title".localized, message: error.localizedDescription))
      )
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleMoveIntoLibrary(items: [SimpleLibraryItem]) {
    let selectedItems = items.compactMap({ self.libraryService.getItem(with: $0.relativePath )})
    let parentFolder = items.first?.parentFolder

    do {
      try self.libraryService.moveItems(selectedItems, inside: nil, moveFiles: true)
      if let parentFolder {
        libraryService.rebuildFolderDetails(parentFolder)
      }
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent(title: "error_title".localized, message: error.localizedDescription))
      )
    }

    self.coordinator.reloadItemsWithPadding(padding: selectedItems.count)
  }

  func handleMoveIntoFolder(_ folder: SimpleLibraryItem, items: [SimpleLibraryItem]) {
    ArtworkService.removeCache(for: folder.relativePath)

    let fetchedItems = items.compactMap({ self.libraryService.getItem(with: $0.relativePath )})

    do {
      try self.libraryService.moveItems(fetchedItems, inside: folder.relativePath, moveFiles: true)
      self.libraryService.rebuildFolderDetails(folder.relativePath)
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent(title: "error_title".localized, message: error.localizedDescription))
      )
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleDelete(items: [SimpleLibraryItem], mode: DeleteMode) {
    let selectedItems = items.compactMap({ self.libraryService.getItem(with: $0.relativePath )})
    let parentFolder = items.first?.parentFolder

    do {
      try self.libraryService.delete(selectedItems, mode: mode)
      if let parentFolder {
        libraryService.rebuildFolderDetails(parentFolder)
      }
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent(title: "error_title".localized, message: error.localizedDescription))
      )
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleOperationCompletion(_ files: [URL]) {
    let library = self.libraryService.getLibrary()
    let processedItems = self.libraryService.insertItems(from: files, into: nil, library: library, processedItems: [])

    do {
      let shouldMoveFiles = self.folderRelativePath != nil

      try self.libraryService.moveItems(processedItems, inside: self.folderRelativePath, moveFiles: shouldMoveFiles)
      if let folderRelativePath = self.folderRelativePath {
        libraryService.rebuildFolderDetails(folderRelativePath)
      }
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent(title: "error_title".localized, message: error.localizedDescription))
      )
      return
    }

    self.coordinator.reloadItemsWithPadding(padding: processedItems.count)

    var availableFolders = [SimpleLibraryItem]()

    if let existingItems = self.libraryService.fetchContents(
      at: self.folderRelativePath,
      limit: nil,
      offset: nil
    ) {
      let existingFolders = existingItems.filter({ $0.type == .folder })

      for folder in existingFolders {
        if processedItems.contains(where: { $0.relativePath == folder.relativePath }) { continue }

        availableFolders.append(folder)
      }
    }

    if processedItems.count > 1 {
      self.coordinator.showOperationCompletedAlert(with: processedItems, availableFolders: availableFolders)
    }
  }

  func handleInsertionIntoLibrary(_ items: [LibraryItem]) {
    do {
      try self.libraryService.moveItems(items, inside: nil, moveFiles: true)
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent(title: "error_title".localized, message: error.localizedDescription))
      )
    }

    self.coordinator.reloadItemsWithPadding(padding: items.count)
  }

  func reorder(item: SimpleLibraryItem, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {
    if let folderRelativePath = folderRelativePath {
      ArtworkService.removeCache(for: folderRelativePath)
    }

    self.libraryService.reorderItem(
      at: item.relativePath,
      inside: self.folderRelativePath,
      sourceIndexPath: sourceIndexPath,
      destinationIndexPath: destinationIndexPath
    )

    self.loadInitialItems(pageSize: self.items.count)
  }

  func updateDefaultArtwork(for theme: SimpleTheme) {
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: theme.linkColor)?.pngData()
  }

  func showMiniPlayer(_ flag: Bool) {
    if let mainCoordinator = self.coordinator?.getMainCoordinator() {
      mainCoordinator.showMiniPlayer(flag)
    }
  }

  func showAddActions() {
    sendEvent(.showActionSheet(
      content: BPSheetContent(
        title: nil,
        message: "import_description".localized,
        actionItems: [
          BPActionItem(
            title: "import_button".localized,
            handler: { [weak self] in
              self?.onTransition?(.showDocumentPicker)
            }
          ),
          BPActionItem(
            title: "create_playlist_button".localized,
            handler: { [weak self] in
              self?.onTransition?(.showCreateFolderAlert(placeholder: nil, items: nil, type: .folder))
            }
          )
        ]
      )
    ))
  }

  func notifyPendingFiles() {
    // Get reference of all the files located inside the Documents, Shared and Inbox folders
    let documentsURLs = ((try? FileManager.default.contentsOfDirectory(
      at: DataManager.getDocumentsFolderURL(),
      includingPropertiesForKeys: nil,
      options: .skipsSubdirectoryDescendants
    )) ?? [])
      .filter {
        $0.lastPathComponent != DataManager.processedFolderName
        && $0.lastPathComponent != DataManager.inboxFolderName
      }

    let sharedURLs = (try? FileManager.default.contentsOfDirectory(
      at: DataManager.getSharedFilesFolderURL(),
      includingPropertiesForKeys: nil,
      options: .skipsSubdirectoryDescendants
    )) ?? []

    let inboxURLs = (try? FileManager.default.contentsOfDirectory(
      at: DataManager.getInboxFolderURL(),
      includingPropertiesForKeys: nil,
      options: .skipsSubdirectoryDescendants
    )) ?? []

    let urls = documentsURLs + sharedURLs + inboxURLs

    guard !urls.isEmpty else { return }

    self.handleNewFiles(urls)
  }

  func handleNewFiles(_ urls: [URL]) {
    self.coordinator.getMainCoordinator()?.getLibraryCoordinator()?.processFiles(urls: urls)
  }

  private func getAvailableFolders(notIn items: [SimpleLibraryItem]) -> [SimpleLibraryItem] {
    var availableFolders = [SimpleLibraryItem]()

    guard
      let existingItems = libraryService.fetchContents(
        at: self.folderRelativePath,
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

  func showSortOptions() {
    sendEvent(.showActionSheet(
      content: BPSheetContent(
        title: "sort_files_title".localized,
        message: nil,
        actionItems: [
          BPActionItem(
            title: "title_button".localized,
            handler: { [weak self] in
              self?.handleSort(by: .metadataTitle)
            }
          ),
          BPActionItem(
            title: "sort_filename_button".localized,
            handler: { [weak self] in
              self?.handleSort(by: .fileName)
            }
          ),
          BPActionItem(
            title: "sort_most_recent_button".localized,
            handler: { [weak self] in
              self?.handleSort(by: .mostRecent)
            }
          ),
          BPActionItem(
            title: "sort_reversed_button".localized,
            handler: { [weak self] in
              self?.handleSort(by: .reverseOrder)
            }
          )
        ]
      )
    ))
  }

  func showItemDetails(_ item: SimpleLibraryItem) {
    self.coordinator.showItemDetails(item)
  }

  func showMoveOptions(selectedItems: [SimpleLibraryItem]) {
    let availableFolders = getAvailableFolders(notIn: selectedItems)

    self.coordinator.showMoveOptions(selectedItems: selectedItems, availableFolders: availableFolders)
  }

  func showDeleteOptions(selectedItems: [SimpleLibraryItem]) {
    self.coordinator.showDeleteAlert(selectedItems: selectedItems)
  }

  func showMoreOptions(selectedItems: [SimpleLibraryItem]) {
    let availableFolders = getAvailableFolders(notIn: selectedItems)

    self.coordinator.showMoreOptionsAlert(selectedItems: selectedItems, availableFolders: availableFolders)
  }

  func showSearchList() {
    onTransition?(
      .showSearchList(relativePath: folderRelativePath, placeholderTitle: getNavigationTitle())
    )
  }

  func handleSort(by option: SortType) {
    self.libraryService.sortContents(at: folderRelativePath, by: option)
    self.reloadItems()
  }

  func handleResetPlaybackPosition(for items: [SimpleLibraryItem]) {
    items.forEach({ self.libraryService.jumpToStart(relativePath: $0.relativePath) })

    self.coordinator.reloadItemsWithPadding()
  }

  func handleMarkAsFinished(for items: [SimpleLibraryItem], flag: Bool) {
    let parentFolder = items.first?.parentFolder

    items.forEach { [unowned self] in
      self.libraryService.markAsFinished(flag: flag, relativePath: $0.relativePath)
    }

    if let parentFolder {
      self.libraryService.rebuildFolderDetails(parentFolder)
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func importData(from item: ImportableItem) {
    let filename = item.suggestedName ?? "\(Date().timeIntervalSince1970).\(item.fileExtension)"

    let destinationURL = DataManager.getDocumentsFolderURL()
      .appendingPathComponent(filename)

    do {
      try item.data.write(to: destinationURL)
    } catch {
      print("Fail to move dropped file to the Documents directory: \(error.localizedDescription)")
    }
  }

  private func sendEvent(_ event: ItemListViewModel.Events) {
    eventsPublisher.send(event)
  }
}

// MARK: - Network related handlers
extension ItemListViewModel {
  /// Get download state of an item
  func getDownloadState(for item: SimpleLibraryItem) -> DownloadState {
    /// Only process if subscription is active
    guard syncService.isActive else { return .downloaded }

    if downloadTasksDictionary[item.relativePath]?.isEmpty == false {
      return .downloading(progress: calculateDownloadProgress(with: item.relativePath))
    }

    let fileURL = item.fileURL

    if item.type == .bound,
       let enumerator = FileManager.default.enumerator(
         at: fileURL,
         includingPropertiesForKeys: nil,
         options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
       ),
       enumerator.nextObject() == nil {
      return .notDownloaded
    }

    if FileManager.default.fileExists(atPath: fileURL.path) {
      return .downloaded
    }

    return .notDownloaded
  }

  /// Download files linked to an item
  /// Note: if the item is a bound book, this will start multiple downloads
  func startDownload(of item: SimpleLibraryItem) {
    sendEvent(.showLoader(flag: true))

    Task { [weak self] in
      guard let self = self else { return }
      do {
        let tasks = try await self.syncService.downloadRemoteFiles(
          for: item.relativePath,
          type: item.type,
          delegate: downloadDelegateInterface
        )
        self.downloadTasksDictionary[item.relativePath] = tasks
        self.ongoingTasksParentReference = tasks.reduce(
          into: ongoingTasksParentReference, { $0[$1.taskDescription!] = item.relativePath }
        )
        self.sendEvent(.showLoader(flag: false))
      } catch {
        self.sendEvent(.showAlert(
          content: BPAlertContent(title: "error_title".localized, message: error.localizedDescription))
        )
      }
    }
  }

  /// Handler called when the download has finished for a task
  func handleDownloadProgressUpdated(task: URLSessionDownloadTask, individualProgress: Double) {
    guard
      let relativePath = task.taskDescription,
      let localItemRelativePath = ongoingTasksParentReference[relativePath],
      let index = items.firstIndex(where: { localItemRelativePath == $0.relativePath })
    else { return }

    let progress: Double
    /// For individual items, the `fractionCompleted` of the current task can be 0
    let calculatedProgress = calculateDownloadProgress(with: localItemRelativePath)
    if calculatedProgress != 0 {
      progress = calculatedProgress
    } else {
      progress = individualProgress
    }

    let indexModified = IndexPath(row: index, section: BPSection.data.rawValue)
    sendEvent(.downloadState(.downloading(progress: progress), indexPath: indexModified))
  }

  /// Calculate the overall download progress for an item (useful for bound books)
  func calculateDownloadProgress(with relativePath: String) -> Double {
    guard let tasks = downloadTasksDictionary[relativePath] else { return 1.0 }

    let completedTasksCount = tasks.filter({ $0.state == .completed }).count
    let runningTasksProgress = tasks.filter({ $0.state == .running })
      .reduce(0.0, { $0 + $1.progress.fractionCompleted })

    return (runningTasksProgress + Double(completedTasksCount)) / Double(tasks.count)
  }

  func handleFinishedDownload(task: URLSessionDownloadTask, location: URL) {
    guard
      let relativePath = task.taskDescription,
      let localItemRelativePath = ongoingTasksParentReference[relativePath]
    else { return }

    /// Remove from dictionary if all the other tasks are already completed
    if let localItemRelativePath = ongoingTasksParentReference[relativePath],
       downloadTasksDictionary[localItemRelativePath]?
      .filter({ $0 != task })
      .allSatisfy({ $0.state == .completed }) == true {
      downloadTasksDictionary[localItemRelativePath] = nil
    }

    /// cleanup individual reference
    ongoingTasksParentReference[relativePath] = nil

    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)

    do {
      /// If there's already something there, replace with new finished download
      if FileManager.default.fileExists(atPath: fileURL.path) {
        try FileManager.default.removeItem(at: fileURL)
      }
      try FileManager.default.moveItem(at: location, to: fileURL)
      libraryService.loadChaptersIfNeeded(relativePath: relativePath, asset: AVAsset(url: fileURL))

      guard let index = items.firstIndex(where: { localItemRelativePath == $0.relativePath }) else { return }

      self.sendEvent(.reloadIndex(IndexPath(row: index, section: BPSection.data.rawValue)))
    } catch {
      self.sendEvent(.showAlert(
        content: BPAlertContent(title: "error_title".localized, message: error.localizedDescription))
      )
    }
  }

  /// Cancel ongoing download tasks for a given item.
  /// This will also delete all files for any partial completed download of bound books
  func cancelDownload(of item: SimpleLibraryItem) {
    guard let tasks = downloadTasksDictionary[item.relativePath] else { return }

    sendEvent(.showAlert(
      content: BPAlertContent(
        message: "Cancel download",
        cancelAction: {},
        confirmationAction: { [tasks, item, weak self] in
          var hasCompletedTasks = false

          for task in tasks {
            guard task.state != .completed else {
              hasCompletedTasks = true
              continue
            }

            task.cancel()
          }

          /// Clean up bound downloads if at least one was finished
          if item.type == .bound,
             hasCompletedTasks {
            do {
              let fileURL = item.fileURL
              try FileManager.default.removeItem(at: fileURL)
              try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: false, attributes: nil)
            } catch {
              self?.sendEvent(.showAlert(
                content: BPAlertContent(title: "error_title".localized, message: error.localizedDescription))
              )
              return
            }
          }

          self?.downloadTasksDictionary[item.relativePath] = nil
          if let index = self?.items.firstIndex(of: item) {
            self?.sendEvent(.reloadIndex(IndexPath(row: index, section: .data)))
          }
        }
      )
    ))
  }

  /// Used to handle downloads via URL scheme
  func handleDownload(_ url: URL) {
    NetworkService.shared.download(from: url) { [weak self] response in
      NotificationCenter.default.post(name: .downloadEnd, object: self)

      if response.error != nil,
         let error = response.error {
        self?.sendEvent(.showAlert(
          content: BPAlertContent(title: "network_error_title".localized, message: error.localizedDescription))
        )
      }

      if let response = response.response, response.statusCode >= 300 {
        self?.sendEvent(.showAlert(
          content: BPAlertContent(title: "network_error_title".localized, message: "Code \(response.statusCode)"))
        )
      }
    }
  }
}
