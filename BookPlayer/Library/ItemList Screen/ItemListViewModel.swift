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

class ItemListViewModel: ViewModelProtocol {
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
    case listDidAppear
    case showQueuedTasks
  }

  enum Events {
    case newData
    case resetEditMode
    case reloadIndex(_ indexPath: IndexPath)
    case downloadState(_ state: DownloadState, indexPath: IndexPath)
    case showAlert(content: BPAlertContent)
    case showLoader(flag: Bool)
    case showProcessingView(Bool, title: String?, subtitle: String?)
  }

  weak var coordinator: ItemListCoordinator!

  let folderRelativePath: String?
  let playerManager: PlayerManagerProtocol
  /// Used to handle single URL downloads
  private let networkClient: NetworkClientProtocol
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  private let listRefreshService: ListSyncRefreshService
  let syncService: SyncServiceProtocol
  private let importManager: ImportManager
  var offset = 0

  public private(set) var defaultArtwork: Data?
  public private(set) var items = [SimpleLibraryItem]()

  var eventsPublisher = InterfaceUpdater<ItemListViewModel.Events>()

  private var bookProgressSubscription: AnyCancellable?
  /// Delegate for progress updates of single downloads by URL
  private var singleDownloadProgressDelegateInterface = BPTaskDownloadDelegate()
  /// Callback to handle actions on this screen
  public var onTransition: BPTransition<Routes>?

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
    networkClient: NetworkClientProtocol,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol,
    importManager: ImportManager,
    listRefreshService: ListSyncRefreshService,
    themeAccent: UIColor
  ) {
    self.folderRelativePath = folderRelativePath
    self.playerManager = playerManager
    self.networkClient = networkClient
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.syncService = syncService
    self.importManager = importManager
    self.listRefreshService = listRefreshService
    self.defaultArtwork = ArtworkService.generateDefaultArtwork(from: themeAccent)?.pngData()
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
      #keyPath(BookPlayerKit.LibraryItem.title),
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

  /// Notify that the UI is presented and ready
  func viewDidAppear() {
    onTransition?(.listDidAppear)
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
    syncService.downloadCompletedPublisher
      .filter({ [weak self] in
        $0.1 == self?.folderRelativePath || $0.2 == self?.folderRelativePath
      })
      .sink { [weak self] (relativePath, initiatingItemPath, _) in
        guard
          let index = self?.items.firstIndex(where: {
            relativePath == $0.relativePath || initiatingItemPath == $0.relativePath
          })
        else { return }

        self?.sendEvent(
          .reloadIndex(IndexPath(row: index, section: BPSection.data.rawValue))
        )
      }.store(in: &disposeBag)

    syncService.downloadProgressPublisher
      .filter({ [weak self] in
        $0.1 == self?.folderRelativePath || $0.2 == self?.folderRelativePath
      })
      .sink { [weak self] (relativePath, initiatingItemPath, _, progress) in
        guard
          let index = self?.items.firstIndex(where: {
            relativePath == $0.relativePath || initiatingItemPath == $0.relativePath
          })
        else { return }

        let indexModified = IndexPath(row: index, section: BPSection.data.rawValue)
        self?.sendEvent(
          .downloadState(.downloading(progress: progress), indexPath: indexModified)
        )
      }.store(in: &disposeBag)

    singleDownloadProgressDelegateInterface.downloadProgressUpdated = { [weak self] (_, progress) in
      let percentage = String(format: "%.2f", progress * 100)
      self?.sendEvent(.showProcessingView(
        true,
        title: "downloading_file_title".localized,
        subtitle: "\("progress_title".localized) \(percentage)%"
      ))
    }

    singleDownloadProgressDelegateInterface.didFinishDownloadingTask = { [weak self] (task, fileURL, error) in
      if let error {
        self?.handleSingleDownloadTaskFinishedWithError(task, error: error)
      } else if let fileURL {
        self?.handleSingleDownloadTaskFinished(task, fileURL: fileURL)
      }
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
    switch getDownloadState(for: item) {
    case .notDownloaded:
      startDownload(of: item)
    case .downloading:
      cancelDownload(of: item)
    case .downloaded:
      switch item.type {
      case .folder:
        playNextBook(in: item)
      case .bound, .book:
        onTransition?(.loadPlayer(relativePath: item.relativePath))
      }
    }
  }

  func reloadItems(pageSizePadding: Int = 0) {
    let pageSize = self.items.count + pageSizePadding
    self.loadInitialItems(pageSize: pageSize)
    sendEvent(.newData)
    sendEvent(.resetEditMode)
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
    Task { @MainActor in
      do {
        let folder = try self.libraryService.createFolder(with: title, inside: self.folderRelativePath)
        await syncService.scheduleUpload(items: [folder])
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
            title: "download_from_url_title".localized,
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
          self?.handleOffloading(of: item)
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

  func handleOffloading(of item: SimpleLibraryItem) {
    verifyUploadTask(for: item) { [weak self] in
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
        self?.reloadItems()
      } catch {
        self?.sendEvent(.showAlert(
          content: BPAlertContent.errorAlert(message: error.localizedDescription)
        ))
      }
    }
  }

  func verifyUploadTask(for item: SimpleLibraryItem, completionHandler: @escaping () -> Void) {
    Task { @MainActor in
      if await syncService.hasUploadTask(for: item.relativePath) {
        sendEvent(.showAlert(
          content: BPAlertContent(
            title: "warning_title".localized,
            message: String(format: "sync_tasks_item_upload_queued".localized, item.relativePath),
            style: .alert,
            actionItems: [
              BPActionItem.cancelAction,
              BPActionItem(title: "Continue", handler: completionHandler)
          ])
        ))
      } else {
        completionHandler()
      }
    }
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
              } else {
                self?.sendEvent(.showAlert(
                  content: BPAlertContent.errorAlert(message: String.localizedStringWithFormat("invalid_url_title".localized, url))
                ))
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

  func refreshAppState() async throws {
    /// Check if there's any pending file to import
    await coordinator.getMainCoordinator()?.getLibraryCoordinator()?.notifyPendingFiles()

    guard syncService.isActive else {
      throw BPSyncRefreshError.disabled
    }

    guard await syncService.queuedJobsCount() == 0 else {
      throw BPSyncRefreshError.scheduledTasks
    }

    await listRefreshService.syncList(at: folderRelativePath, alertPresenter: self)
  }

  func showQueuedTasks() {
    onTransition?(.showQueuedTasks)
  }
}

// MARK: - Import related functions
extension ItemListViewModel {
  func handleNewFiles(_ urls: [URL]) {
    let temporaryDirectoryPath = FileManager.default.temporaryDirectory.absoluteString
    let documentsFolder = DataManager.getDocumentsFolderURL()

    for url in urls {
      /// At some point (iOS 17?), the OS stopped sending the picked files to the Documents/Inbox folder, instead
      /// it's now sent to a temp folder that can't be relied on to keep the file existing until the import is finished
      if url.absoluteString.contains(temporaryDirectoryPath) {
        let destinationURL = documentsFolder.appendingPathComponent(url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
          try! FileManager.default.copyItem(at: url, to: destinationURL)
        }
      } else {
        importManager.process(url)
      }
    }
  }

  func handleOperationCompletion(_ files: [URL], suggestedFolderName: String?) {
    guard !files.isEmpty else { return }

    Task { @MainActor in
      let processedItems = libraryService.insertItems(from: files)
      var itemIdentifiers = processedItems.map({ $0.relativePath })
      do {
        await syncService.scheduleUpload(items: processedItems)
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

      showOperationCompletedAlert(
        itemIdentifiers: itemIdentifiers,
        hasOnlyBooks: processedItems.allSatisfy({ $0.type == .book }),
        availableFolders: availableFolders,
        suggestedFolderName: suggestedFolderName
      )
    }
  }

  // swiftlint:disable:next function_body_length
  func showOperationCompletedAlert(
    itemIdentifiers: [String],
    hasOnlyBooks: Bool,
    availableFolders: [SimpleLibraryItem],
    suggestedFolderName: String?
  ) {
    let hasParentFolder = folderRelativePath != nil

    var firstTitle: String?
    if let suggestedFolderName {
      firstTitle = suggestedFolderName
    } else if let relativePath = itemIdentifiers.first {
      firstTitle = libraryService.getItemProperty(
        #keyPath(BookPlayerKit.LibraryItem.title), relativePath: relativePath
      ) as? String
    }

    var actions = [BPActionItem]()

    if hasParentFolder {
      actions.append(BPActionItem(title: "current_playlist_title".localized))
    }

    actions.append(BPActionItem(
      title: "library_title".localized,
      handler: { [hasParentFolder, itemIdentifiers, weak self] in
        guard hasParentFolder else { return }

        self?.importIntoLibrary(itemIdentifiers)
      }
    ))

    actions.append(BPActionItem(
      title: "new_playlist_button".localized,
      handler: { [firstTitle, weak self] in
        let placeholder = firstTitle ?? "new_playlist_button".localized

        self?.showCreateFolderAlert(
          placeholder: placeholder,
          with: itemIdentifiers,
          type: .folder
        )
      }
    ))

    actions.append(BPActionItem(
      title: "existing_playlist_button".localized,
      isEnabled: !availableFolders.isEmpty,
      handler: { [itemIdentifiers, availableFolders, weak self] in
        self?.onTransition?(.showItemSelectionScreen(
          availableItems: availableFolders,
          selectionHandler: { selectedFolder in
            self?.importIntoFolder(selectedFolder, items: itemIdentifiers, type: .folder)
          }
        ))
      }
    ))

    actions.append(BPActionItem(
      title: "bound_books_create_button".localized,
      isEnabled: hasOnlyBooks,
      handler: { [firstTitle, weak self] in
        let placeholder = firstTitle ?? "bound_books_new_title_placeholder".localized

        self?.showCreateFolderAlert(placeholder: placeholder, with: itemIdentifiers, type: .bound)
      }
    ))

    /// Register that at least one import operation has completed
    BPSKANManager.updateConversionValue(.import)

    sendEvent(.showAlert(
      content: BPAlertContent(
        title: String.localizedStringWithFormat("import_alert_title".localized, itemIdentifiers.count),
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
    let filename: String

    if let suggestedName = item.suggestedName {
      let pathExtension = (suggestedName as NSString).pathExtension
      /// Use  `suggestedFileExtension` only if the curret name does not include an extension
      if pathExtension.isEmpty {
        filename = "\(suggestedName).\(item.suggestedFileExtension)"
      } else {
        filename = suggestedName
      }
    } else {
      /// Fallback if the provider didn't have a suggested name
      filename = "\(Date().timeIntervalSince1970).\(item.suggestedFileExtension)"
    }

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
  func getDownloadState(for item: SimpleLibraryItem) -> DownloadState {
    return syncService.getDownloadState(for: item)
  }
  /// Download files linked to an item
  /// Note: if the item is a bound book, this will start multiple downloads
  func startDownload(of item: SimpleLibraryItem) {
    Task { @MainActor in
      sendEvent(.showLoader(flag: true))

      do {
        let fileURL = item.fileURL
        /// Create backing folder if it does not exist
        if item.type == .folder || item.type == .bound {
          try DataManager.createBackingFolderIfNeeded(fileURL)
        }

        try await self.syncService.downloadRemoteFiles(for: item)
        self.sendEvent(.showLoader(flag: false))
      } catch {
        self.sendEvent(.showLoader(flag: false))
        self.sendEvent(.showAlert(
          content: BPAlertContent.errorAlert(message: error.localizedDescription)
        ))
      }
    }
  }

  /// Cancel ongoing download tasks for a given item.
  /// This will also delete all files for any partial completed download of bound books
  func cancelDownload(of item: SimpleLibraryItem) {
    sendEvent(.showAlert(
      content: BPAlertContent(
        message: "cancel_download_title".localized,
        style: .alert,
        actionItems: [
          BPActionItem(
            title: "ok_button".localized,
            handler: { [item, weak self] in
              do {
                try self?.syncService.cancelDownload(of: item)
              } catch {
                self?.sendEvent(.showAlert(
                  content: BPAlertContent.errorAlert(message: error.localizedDescription)
                ))
                return
              }

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
    sendEvent(.showProcessingView(true, title: "downloading_file_title".localized, subtitle: "\("progress_title".localized) 0%"))

    _ = networkClient.download(url: url, delegate: singleDownloadProgressDelegateInterface)
  }

  // TODO: Move functionality related to single-donwload into a separate service, and listen to publisher for events
  func handleSingleDownloadTaskFinished(_ task: URLSessionTask, fileURL: URL) {
    sendEvent(.showProcessingView(false, title: nil, subtitle: nil))
    let filename = task.response?.suggestedFilename
    ?? task.originalRequest?.url?.lastPathComponent
    ?? fileURL.lastPathComponent

    do {
      try FileManager.default.moveItem(
        at: fileURL,
        to: DataManager.getDocumentsFolderURL().appendingPathComponent(filename)
      )
    } catch {
      sendEvent(.showAlert(
        content: BPAlertContent.errorAlert(
          title: "error_title".localized,
          message: error.localizedDescription
        )
      ))
    }
  }

  func handleSingleDownloadTaskFinishedWithError(_ task: URLSessionTask, error: Error?) {
    sendEvent(.showProcessingView(false, title: nil, subtitle: nil))
    if let error {
      sendEvent(.showAlert(
        content: BPAlertContent.errorAlert(
          title: "network_error_title".localized,
          message: error.localizedDescription
        )
      ))
      return
    }

    guard let statusCode = (task.response as? HTTPURLResponse)?.statusCode,
          statusCode >= 400 else {
      return
    }

    sendEvent(.showAlert(
      content: BPAlertContent.errorAlert(
        title: "network_error_title".localized,
        message: "Code \(statusCode)\n\(HTTPURLResponse.localizedString(forStatusCode: statusCode))"
      )
    ))
  }
}

extension ItemListViewModel: AlertPresenter {
  func showAlert(_ title: String?, message: String?, completion: (() -> Void)?) {
    sendEvent(.showAlert(
      content: BPAlertContent(
        title: title,
        message: message,
        style: .alert,
        actionItems: [BPActionItem.okAction]
      )
    ))
  }
  
  func showLoader() {
    sendEvent(.showLoader(flag: true))
  }
  
  func stopLoader() {
    sendEvent(.showLoader(flag: false))
  }
}
