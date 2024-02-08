//
//  LibraryListCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import UIKit

class LibraryListCoordinator: ItemListCoordinator, UINavigationControllerDelegate {
  weak var tabBarController: UITabBarController?

  var fileSubscription: AnyCancellable?
  var importOperationSubscription: AnyCancellable?
  /// Reference to know if the import screen is already being shown (or in the process of showing)
  weak var importCoordinator: ImportCoordinator?
  /// Reference to ongoing library fetch task
  var contentsFetchTask: Task<(), Error>?

  private var disposeBag = Set<AnyCancellable>()

  // swiftlint:disable:next function_body_length
  override func start() {
    let vc = ItemListViewController.instantiate(from: .Main)
    let viewModel = ItemListViewModel(
      folderRelativePath: nil,
      playerManager: self.playerManager,
      networkClient: NetworkClient(),
      libraryService: self.libraryService,
      playbackService: self.playbackService,
      syncService: self.syncService, 
      importManager: importManager,
      listRefreshService: listRefreshService,
      themeAccent: ThemeManager.shared.currentTheme.linkColor
    )
    viewModel.onTransition = { route in
      switch route {
      case .showFolder(let relativePath):
        self.showFolder(relativePath)
      case .loadPlayer(let relativePath):
        self.loadPlayer(relativePath)
      case .showDocumentPicker:
        self.showDocumentPicker()
      case .showSearchList(let relativePath, let placeholderTitle):
        self.showSearchList(at: relativePath, placeholderTitle: placeholderTitle)
      case .showItemDetails(let item):
        self.showItemDetails(item)
      case .showExportController(let items):
        self.showExportController(for: items)
      case .showItemSelectionScreen(let availableItems, let selectionHandler):
        self.showItemSelectionScreen(availableItems: availableItems, selectionHandler: selectionHandler)
      case .showMiniPlayer(let flag):
        self.showMiniPlayer(flag: flag)
      case .listDidAppear:
        self.handleLibraryLoaded()
      case .showQueuedTasks:
        self.showQueuedTasks()
      }
    }
    viewModel.coordinator = self
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .automatic
    vc.tabBarItem = UITabBarItem(
      title: "library_title".localized,
      image: UIImage(systemName: "books.vertical"),
      selectedImage: UIImage(systemName: "books.vertical.fill")
    )

    flow.startPresentation(vc, animated: false)

    if let tabBarController = tabBarController {
      let newControllersArray = (tabBarController.viewControllers ?? []) + [flow.navigationController]
      tabBarController.setViewControllers(newControllersArray, animated: false)
    }

    if let appDelegate = AppDelegate.shared {
      for action in appDelegate.pendingURLActions {
        ActionParserService.handleAction(action)
      }
    }

    self.documentPickerDelegate = vc

    AppDelegate.shared?.watchConnectivityService?.startSession()
  }

  func handleLibraryLoaded() {
    loadLastBookIfNeeded()
    syncList()
    bindImportObserverIfNeeded()
  }

  func bindImportObserverIfNeeded() {
    guard
      fileSubscription == nil,
      AppDelegate.shared?.activeSceneDelegate != nil
    else { return }

    fileSubscription = importManager.observeFiles()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] files in
      guard let self = self,
            !files.isEmpty,
            self.shouldShowImportScreen() else { return }

      self.showImport()
    }

    importOperationSubscription = importManager.operationPublisher.sink(receiveValue: { [weak self] operation in
      guard 
        let self,
        let lastItemListViewController = self.flow.navigationController.viewControllers.last as? ItemListViewController
      else {
        return
      }

      lastItemListViewController.setEditing(false, animated: false)
      let loadingTitle = String.localizedStringWithFormat("import_processing_description".localized, operation.files.count)
      lastItemListViewController.showLoadView(true, title: loadingTitle)

      operation.completionBlock = {
        DispatchQueue.main.async {
          lastItemListViewController.setEditing(false, animated: false)
          lastItemListViewController.showLoadView(false)
          lastItemListViewController.viewModel
            .handleOperationCompletion(operation.processedFiles, suggestedFolderName: operation.suggestedFolderName)
        }
      }

      self.importManager.start(operation)
    })

    notifyPendingFiles()
  }

  @MainActor
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
        && $0.lastPathComponent != DataManager.backupFolderName
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

    processFiles(urls: urls)
  }

  func loadLastBookIfNeeded() {
    guard
      let libraryItem = libraryService.getLibraryLastItem()
    else { return }

    AppDelegate.shared?.loadPlayer(
      libraryItem.relativePath,
      autoplay: false,
      showPlayer: { [weak self] in
        if UserDefaults.standard.bool(forKey: Constants.UserActivityPlayback) {
          UserDefaults.standard.removeObject(forKey: Constants.UserActivityPlayback)
          self?.playerManager.play()
        }

        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.showPlayer) {
          UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.showPlayer)
          self?.showPlayer()
        }
      },
      alertPresenter: self,
      recordAsLastBook: false
    )
  }

  func processFiles(urls: [URL]) {
    for url in urls {
      self.importManager.process(url)
    }
  }

  func showImport() {
    guard 
      let topVC = AppDelegate.shared?.activeSceneDelegate?.startingNavigationController.getTopVisibleViewController()
    else { return }

    let coordinator = ImportCoordinator(
      flow: .modalFlow(presentingController: topVC),
      importManager: self.importManager
    )
    importCoordinator = coordinator
    coordinator.start()
  }

  func shouldShowImportScreen() -> Bool {
    return importCoordinator == nil
  }

  func syncLastFolderList() {
    let viewControllers = flow.navigationController.viewControllers
    guard
      viewControllers.count > 1,
      let lastItemListViewController = viewControllers.last as? ItemListViewController
    else { return }

    lastItemListViewController.viewModel.viewDidAppear()
  }

  func handleDownloadAction(url: URL) {
    guard
      let libraryListViewController = flow.navigationController.viewControllers.first as? ItemListViewController
    else { return }

    libraryListViewController.setEditing(false, animated: false)
    libraryListViewController.viewModel.handleDownload(url)
  }

  override func syncList() {
    /// Process any deferred progress calculations for folders
    if playbackService.processFoldersStaleProgress() {
      reloadItemsWithPadding()
    }

    guard syncService.canSyncListContents(at: nil, ignoreLastTimestamp: false) else { return }

    /// Create new task to sync the library and the last played
    contentsFetchTask?.cancel()
    contentsFetchTask = Task {
      await listRefreshService.syncList(at: nil, alertPresenter: self)
      await MainActor.run {
        self.reloadItemsWithPadding()
      }
    }
  }
}

extension LibraryListCoordinator: PlaybackSyncProgressDelegate {
  func waitForSyncInProgress() async {
    _ = await contentsFetchTask?.result
  }
}
