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
    case showSearchList(relativePath: String?, placeholderTitle: String)
    case showItemDetails(item: SimpleLibraryItem)
    case showExportController(items: [SimpleLibraryItem])
    case showItemSelectionScreen(
      availableItems: [SimpleLibraryItem],
      selectionHandler: (SimpleLibraryItem) -> Void
    )
    case showMiniPlayer(flag: Bool)
  }

  enum Events {
    case newData
    case reloadIndex(_ indexPath: IndexPath)
    case downloadState(_ state: DownloadState, indexPath: IndexPath)
    case showAlert(content: BPAlertContent)
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

    return libraryService.getItemProperty(
      #keyPath(LibraryItem.title),
      relativePath: folderRelativePath
    ) as? String
    ?? ""
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
    } else if let nextPlayableItem = try? self.playbackService.getFirstPlayableItem(
        in: item,
        isUnfinished: true
      ),
      let nextItem = libraryService.getSimpleItem(with: nextPlayableItem.relativePath) {
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

  func createFolder(with title: String, items: [String]? = nil, type: SimpleItemType) {
    do {
      let folder = try self.libraryService.createFolder(with: title, inside: self.folderRelativePath)
      try syncService.scheduleUpload(items: [folder])
      if let fetchedItems = items {
        try libraryService.moveItems(fetchedItems, inside: folder.relativePath)
        syncService.scheduleMove(items: fetchedItems, to: folder.relativePath)
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
        content: BPAlertContent.errorAlert(message: error.localizedDescription)
      ))
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
        content: BPAlertContent.errorAlert(message: error.localizedDescription)
      ))
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleMoveIntoLibrary(items: [SimpleLibraryItem]) {
    let selectedItems = items.compactMap({ $0.relativePath })
    let parentFolder = items.first?.parentFolder

    do {
      try libraryService.moveItems(selectedItems, inside: nil)
      syncService.scheduleMove(items: selectedItems, to: nil)
      if let parentFolder {
        libraryService.rebuildFolderDetails(parentFolder)
      }
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent.errorAlert(message: error.localizedDescription)
      ))
    }

    self.coordinator.reloadItemsWithPadding(padding: selectedItems.count)
  }

  func handleMoveIntoFolder(_ folder: SimpleLibraryItem, items: [SimpleLibraryItem]) {
    ArtworkService.removeCache(for: folder.relativePath)

    let fetchedItems = items.compactMap({ $0.relativePath })

    do {
      try libraryService.moveItems(fetchedItems, inside: folder.relativePath)
      syncService.scheduleMove(items: fetchedItems, to: folder.relativePath)
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent.errorAlert(message: error.localizedDescription)
      ))
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func handleDelete(items: [SimpleLibraryItem], mode: DeleteMode) {
    let parentFolder = items.first?.parentFolder

    do {
      try libraryService.delete(items, mode: mode)

      if let parentFolder {
        libraryService.rebuildFolderDetails(parentFolder)
      }

      syncService.scheduleDelete(items, mode: mode)
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent.errorAlert(message: error.localizedDescription)
      ))
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func reorder(item: SimpleLibraryItem, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {
    if let folderRelativePath = folderRelativePath {
      ArtworkService.removeCache(for: folderRelativePath)
    }

    self.libraryService.reorderItem(
      with: item.relativePath,
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
    onTransition?(.showMiniPlayer(flag: flag))
  }

  func showAddActions() {
    sendEvent(.showAlert(
      content: BPAlertContent(
        title: nil,
        message: "import_description".localized,
        style: .actionSheet,
        actionItems: [
          BPActionItem(
            title: "import_button".localized,
            handler: { [weak self] in
              self?.onTransition?(.showDocumentPicker)
            }
          ),
          BPActionItem(
            title: "download_title".localized,
            handler: { [weak self] in
              self?.showDownloadFromUrlAlert()
            }
          ),
          BPActionItem(
            title: "create_playlist_button".localized,
            handler: { [weak self] in
              self?.showCreateFolderAlert(
                placeholder: nil,
                with: nil,
                type: .folder
              )
            }
          ),
          BPActionItem.cancelAction
        ]
      )
    ))
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
    sendEvent(.showAlert(
      content: BPAlertContent(
        title: "sort_files_title".localized,
        message: nil,
        style: .actionSheet,
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
          ),
          BPActionItem.cancelAction
        ]
      )
    ))
  }

  func showItemDetails(_ item: SimpleLibraryItem) {
    onTransition?(.showItemDetails(item: item))
  }

  func showMoveOptions(selectedItems: [SimpleLibraryItem]) {
    let availableFolders = getAvailableFolders(notIn: selectedItems)

    showMoveOptions(selectedItems: selectedItems, availableFolders: availableFolders)
  }

  func showDeleteAlert(selectedItems: [SimpleLibraryItem]) {
    var actions = [BPActionItem]()
    var alertTitle: String
    var alertMessage: String?

    if selectedItems.count == 1,
       let item = selectedItems.first {
      alertTitle = String(format: "delete_single_item_title".localized, item.title)
      alertMessage = nil
    } else {
      alertTitle = String.localizedStringWithFormat("delete_multiple_items_title".localized, selectedItems.count)
      alertMessage = "delete_multiple_items_description".localized
    }

    var deleteActionTitle = "delete_button".localized

    if selectedItems.count == 1,
       let item = selectedItems.first,
       item.type == .folder {
      deleteActionTitle = "delete_deep_button".localized

      alertTitle = String(format: "delete_single_item_title".localized, item.title)
      alertMessage = "delete_single_playlist_description".localized

      actions.append(
        BPActionItem(
          title: "delete_shallow_button".localized,
          handler: { [weak self] in
            self?.handleDelete(items: selectedItems, mode: .shallow)
          }
        )
      )
    }

    actions.append(
      BPActionItem(
        title: deleteActionTitle,
        style: .destructive,
        handler: { [weak self] in
          if selectedItems.contains(where: { $0.relativePath == self?.playerManager.currentItem?.relativePath }) {
            self?.playerManager.stop()
          }
          self?.handleDelete(items: selectedItems, mode: .deep)
        }
      )
    )
    actions.append(BPActionItem.cancelAction)

    sendEvent(.showAlert(
      content: BPAlertContent(
        title: alertTitle,
        message: alertMessage,
        style: .alert,
        actionItems: actions
      )
    ))
  }

  // swiftlint:disable:next function_body_length
  func showMoreOptions(selectedItems: [SimpleLibraryItem]) {
    guard let item = selectedItems.first else { return }

    let isSingle = selectedItems.count == 1

    var actions = [
      BPActionItem(
        title: "details_title".localized,
        isEnabled: isSingle,
        handler: { [weak self] in
          self?.onTransition?(.showItemDetails(item: item))
        }
      ),
      BPActionItem(
        title: "move_title".localized,
        handler: { [weak self] in
          guard let self = self else { return }

          self.showMoveOptions(
            selectedItems: selectedItems,
            availableFolders: self.getAvailableFolders(notIn: selectedItems)
          )
        }
      ),
      BPActionItem(
        title: "export_button".localized,
        handler: { [weak self] in
          self?.onTransition?(.showExportController(items: selectedItems))
        }
      ),
      BPActionItem(
        title: "jump_start_title".localized,
        handler: { [weak self] in
          self?.handleResetPlaybackPosition(for: selectedItems)
        }
      )
    ]

    let areFinished = selectedItems.filter({ !$0.isFinished }).isEmpty
    let markTitle = areFinished ? "mark_unfinished_title".localized : "mark_finished_title".localized

    actions.append(
      BPActionItem(
        title: markTitle,
        handler: { [areFinished, weak self] in
          self?.handleMarkAsFinished(for: selectedItems, flag: !areFinished)
        }
      )
    )

    let boundBookAction: BPActionItem

    if selectedItems.allSatisfy({ $0.type == .bound }) {
      boundBookAction = BPActionItem(
        title: "bound_books_undo_alert_title".localized,
        handler: { [weak self] in
          self?.updateFolders(selectedItems, type: .folder)
        }
      )
    } else {
      let isActionEnabled = (selectedItems.count > 1 && selectedItems.allSatisfy({ $0.type == .book }))
      || (isSingle && item.type == .folder)

      boundBookAction = BPActionItem(
        title: "bound_books_create_button".localized,
        isEnabled: isActionEnabled,
        handler: { [weak self] in
          if isSingle {
            self?.updateFolders(selectedItems, type: .bound)
          } else {
            self?.showCreateFolderAlert(
              placeholder: item.title,
              with: selectedItems.map { $0.relativePath },
              type: .bound
            )
          }
        }
      )
    }

    actions.append(boundBookAction)

    if syncService.isActive {
      let title: String
      let handler: () -> Void

      switch getDownloadState(for: item) {
      case .notDownloaded:
        title = "download_title".localized
        handler = { [weak self] in
          self?.startDownload(of: item)
        }
      case .downloading:
        title = "cancel_download_title".localized
        handler = { [weak self] in
          self?.cancelDownload(of: item)
        }
      case .downloaded:
        title = "remove_downloaded_file_title".localized
        handler = { [weak self] in
          do {
            let fileURL = item.fileURL
            try FileManager.default.removeItem(at: fileURL)
            if item.type == .bound {
              try FileManager.default.createDirectory(
                at: fileURL,
                withIntermediateDirectories: false,
                attributes: nil
              )
            }
            self?.reloadItems()
          } catch {
            self?.sendEvent(.showAlert(
              content: BPAlertContent.errorAlert(message: error.localizedDescription)
            ))
            return
          }
        }
      }
      actions.append(
        BPActionItem(
          title: title,
          isEnabled: isSingle,
          handler: handler
        )
      )
    }

    actions.append(
      BPActionItem(
        title: "delete_button".localized,
        style: .destructive,
        handler: { [weak self] in
          self?.showDeleteAlert(selectedItems: selectedItems)
        }
      )
    )
    actions.append(BPActionItem.cancelAction)

    sendEvent(.showAlert(
      content: BPAlertContent(
        title: isSingle ? item.title : "options_button".localized,
        style: .actionSheet,
        actionItems: actions
      )
    ))
  }

  func showMoveOptions(selectedItems: [SimpleLibraryItem], availableFolders: [SimpleLibraryItem]) {
    var actions = [BPActionItem]()

    if folderRelativePath != nil {
      actions.append(
        BPActionItem(
          title: "library_title".localized,
          handler: { [weak self] in
            self?.handleMoveIntoLibrary(items: selectedItems)
          }
        )
      )
    }

    actions.append(
      BPActionItem(
        title: "new_playlist_button".localized,
        handler: { [weak self] in
          self?.showCreateFolderAlert(
            placeholder: selectedItems.first?.title,
            with: selectedItems.map { $0.relativePath },
            type: .folder
          )
        }
      )
    )

    actions.append(
      BPActionItem(
        title: "existing_playlist_button".localized,
        isEnabled: !availableFolders.isEmpty,
        handler: { [weak self] in
          self?.onTransition?(.showItemSelectionScreen(
            availableItems: availableFolders,
            selectionHandler: { folder in
              self?.handleMoveIntoFolder(folder, items: selectedItems)
          }))
        }
      )
    )

    actions.append(BPActionItem.cancelAction)

    sendEvent(.showAlert(
      content: BPAlertContent(
        title: "choose_destination_title".localized,
        style: .alert,
        actionItems: actions
      )
    ))
  }

  func showCreateFolderAlert(
    placeholder: String? = nil,
    with items: [String]? = nil,
    type: SimpleItemType = .folder
  ) {
    let alertTitle: String
    let alertMessage: String
    let alertPlaceholderDefault: String

    switch type {
    case .folder:
      alertTitle = "create_playlist_title".localized
      alertMessage = ""
      alertPlaceholderDefault = "new_playlist_button".localized
    case .bound:
      alertTitle = "bound_books_create_alert_title".localized
      alertMessage = "bound_books_create_alert_description".localized
      alertPlaceholderDefault = "bound_books_new_title_placeholder".localized
    case .book:
      return
    }

    sendEvent(.showAlert(
      content: BPAlertContent(
        title: alertTitle,
        message: alertMessage,
        style: .alert,
        textInputPlaceholder: placeholder ?? alertPlaceholderDefault,
        actionItems: [
          BPActionItem(
            title: "create_button".localized,
            inputHandler: { [items, type, weak self] title in
              self?.createFolder(with: title, items: items, type: type)
            }
          ),
          BPActionItem.cancelAction
        ]
      )
    ))
  }

  func showDownloadFromUrlAlert() {
    sendEvent(.showAlert(
      content: BPAlertContent(
        title: "download_from_url_title".localized,
        style: .alert,
        textInputPlaceholder: "https://",
        actionItems: [
          BPActionItem(
            title: "download_title".localized,
            inputHandler: { [weak self] url in
              if let bookUrl = URL(string: url) {
                self?.handleDownload(bookUrl)
              }
            }
          ),
          BPActionItem.cancelAction
        ]
      )
    ))
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

  private func sendEvent(_ event: ItemListViewModel.Events) {
    eventsPublisher.send(event)
  }
}

// MARK: - Import related functions
extension ItemListViewModel {
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

  func handleOperationCompletion(_ files: [URL]) {
    let processedItems = libraryService.insertItems(from: files)
    var itemIdentifiers = processedItems.map({ $0.relativePath })
    do {
      try syncService.scheduleUpload(items: processedItems)
      /// Move imported files to current selected folder so the user can see them
      if let folderRelativePath {
        try libraryService.moveItems(itemIdentifiers, inside: folderRelativePath)
        syncService.scheduleMove(items: itemIdentifiers, to: folderRelativePath)
        /// Update identifiers after moving for the follow up action alert
        itemIdentifiers = itemIdentifiers.map({ "\(folderRelativePath)/\($0)" })
      }
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent.errorAlert(message: error.localizedDescription)
      ))
      return
    }

    self.coordinator.reloadItemsWithPadding(padding: itemIdentifiers.count)

    let availableFolders = self.libraryService.getItems(
      notIn: itemIdentifiers,
      parentFolder: folderRelativePath
    )?.filter({ $0.type == .folder }) ?? []

    showOperationCompletedAlert(with: itemIdentifiers, availableFolders: availableFolders)
  }

  func showOperationCompletedAlert(with items: [String], availableFolders: [SimpleLibraryItem]) {
    let hasParentFolder = folderRelativePath != nil

    var firstTitle: String?
    if let relativePath = items.first {
      firstTitle = libraryService.getItemProperty(#keyPath(LibraryItem.title), relativePath: relativePath) as? String
    }

    var actions = [BPActionItem]()

    if hasParentFolder {
      actions.append(BPActionItem(title: "current_playlist_title".localized))
    }

    actions.append(BPActionItem(
      title: "library_title".localized,
      handler: { [hasParentFolder, items, weak self] in
        guard hasParentFolder else { return }

        self?.importIntoLibrary(items)
      }
    ))

    actions.append(BPActionItem(
      title: "new_playlist_button".localized,
      handler: { [firstTitle, weak self] in
        let placeholder = firstTitle ?? "new_playlist_button".localized

        self?.showCreateFolderAlert(
          placeholder: placeholder,
          with: items,
          type: .folder
        )
      }
    ))

    actions.append(BPActionItem(
      title: "existing_playlist_button".localized,
      isEnabled: !availableFolders.isEmpty,
      handler: { [items, availableFolders, weak self] in
        self?.onTransition?(.showItemSelectionScreen(
          availableItems: availableFolders,
          selectionHandler: { selectedFolder in
            self?.importIntoFolder(selectedFolder, items: items, type: .folder)
          }
        ))
      }
    ))

    actions.append(BPActionItem(
      title: "bound_books_create_button".localized,
      isEnabled: items is [Book],
      handler: { [firstTitle, weak self] in
        let placeholder = firstTitle ?? "bound_books_new_title_placeholder".localized

        self?.showCreateFolderAlert(placeholder: placeholder, with: items, type: .bound)
      }
    ))

    sendEvent(.showAlert(
      content: BPAlertContent(
        title: String.localizedStringWithFormat("import_alert_title".localized, items.count),
        style: .alert,
        actionItems: actions
      )
    ))
  }

  func importIntoFolder(_ folder: SimpleLibraryItem, items: [String], type: SimpleItemType) {
    do {
      try libraryService.moveItems(items, inside: folder.relativePath)
      syncService.scheduleMove(items: items, to: folder.relativePath)
      try libraryService.updateFolder(at: folder.relativePath, type: type)
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent.errorAlert(message: error.localizedDescription)
      ))
    }

    self.coordinator.reloadItemsWithPadding()
  }

  func importIntoLibrary(_ items: [String]) {
    do {
      try libraryService.moveItems(items, inside: nil)
      syncService.scheduleMove(items: items, to: nil)
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent.errorAlert(message: error.localizedDescription)
      ))
    }

    self.coordinator.reloadItemsWithPadding(padding: items.count)
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
          content: BPAlertContent.errorAlert(message: error.localizedDescription)
        ))
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
        content: BPAlertContent.errorAlert(message: error.localizedDescription)
      ))
    }
  }

  /// Cancel ongoing download tasks for a given item.
  /// This will also delete all files for any partial completed download of bound books
  func cancelDownload(of item: SimpleLibraryItem) {
    guard let tasks = downloadTasksDictionary[item.relativePath] else { return }

    sendEvent(.showAlert(
      content: BPAlertContent(
        message: "cancel_download_title".localized,
        style: .alert,
        actionItems: [
          BPActionItem(
            title: "ok_button".localized,
            handler: { [tasks, item, weak self] in
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
                    content: BPAlertContent.errorAlert(message: error.localizedDescription)
                  ))
                  return
                }
              }

              self?.downloadTasksDictionary[item.relativePath] = nil
              if let index = self?.items.firstIndex(of: item) {
                self?.sendEvent(.reloadIndex(IndexPath(row: index, section: .data)))
              }
            }
          ),
          BPActionItem.cancelAction
        ]
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
          content: BPAlertContent.errorAlert(
            title: "network_error_title".localized,
            message: error.localizedDescription
          )
        ))
      }

      if let response = response.response, response.statusCode >= 300 {
        self?.sendEvent(.showAlert(
          content: BPAlertContent.errorAlert(
            title: "network_error_title".localized,
            message: "Code \(response.statusCode)"
          )
        ))
      }
    }
  }
}
