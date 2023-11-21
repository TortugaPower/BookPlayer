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
  let importManager: ImportManager

  var fileSubscription: AnyCancellable?
  var importOperationSubscription: AnyCancellable?
  /// Reference to know if the import screen is already being shown (or in the process of showing)
  weak var importCoordinator: ImportCoordinator?

  private var disposeBag = Set<AnyCancellable>()

  init(
    flow: BPCoordinatorPresentationFlow,
    playerManager: PlayerManagerProtocol,
    importManager: ImportManager,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.importManager = importManager

    super.init(
      flow: flow,
      playerManager: playerManager,
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService
    )
  }

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

    self.fileSubscription = self.importManager.observeFiles().sink { [weak self] files in
      guard let self = self,
            !files.isEmpty,
            self.shouldShowImportScreen() else { return }

      self.showImport()
    }

    self.importOperationSubscription = self.importManager.operationPublisher.sink(receiveValue: { [weak self] operation in
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
      alertPresenter: self
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
    Task { @MainActor in
      do {
        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents) == true {
          try await syncService.syncListContents(at: nil)
        } else {
          try await syncService.syncLibraryContents()

          UserDefaults.standard.set(
            true,
            forKey: Constants.UserDefaults.hasScheduledLibraryContents
          )
        }

        reloadItemsWithPadding()
      } catch BPSyncError.reloadLastBook(let relativePath) {
        reloadItemsWithPadding()
        reloadLastBook(relativePath: relativePath)
      } catch BPSyncError.differentLastBook(let relativePath) {
        reloadItemsWithPadding()
        setSyncedLastPlayedItem(relativePath: relativePath)
      } catch {
        Self.logger.trace("Sync contents error: \(error.localizedDescription)")
      }

      /// Process any deferred progress calculations for folders
      if playbackService.processFoldersStaleProgress() {
        reloadItemsWithPadding()
      }
    }
  }

  func reloadLastBook(relativePath: String) {
    let wasPlaying = playerManager.isPlaying
    playerManager.stop()
    AppDelegate.shared?.loadPlayer(
      relativePath,
      autoplay: wasPlaying,
      showPlayer: nil,
      alertPresenter: self
    )
  }

  func setSyncedLastPlayedItem(relativePath: String) {
    /// Only continue overriding local book if it's not currently playing
    guard playerManager.isPlaying == false else { return }

    libraryService.setLibraryLastBook(with: relativePath)
    AppDelegate.shared?.loadPlayer(
      relativePath,
      autoplay: false,
      showPlayer: nil,
      alertPresenter: self
    )
  }
}
