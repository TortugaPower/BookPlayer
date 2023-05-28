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

class LibraryListCoordinator: ItemListCoordinator {
  weak var tabBarController: UITabBarController?
  let importManager: ImportManager

  var fileSubscription: AnyCancellable?
  var importOperationSubscription: AnyCancellable?
  private var disposeBag = Set<AnyCancellable>()

  init(
    navigationController: UINavigationController,
    playerManager: PlayerManagerProtocol,
    importManager: ImportManager,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.importManager = importManager

    super.init(
      navigationController: navigationController,
      playerManager: playerManager,
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService
    )

    bindImportObserver()
  }

  // swiftlint:disable:next function_body_length
  override func start() {
    let vc = ItemListViewController.instantiate(from: .Main)
    let viewModel = ItemListViewModel(
      folderRelativePath: nil,
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      playbackService: self.playbackService,
      syncService: self.syncService,
      themeAccent: ThemeManager.shared.currentTheme.linkColor
    )
    viewModel.onTransition = { [weak self] route in
      switch route {
      case .showFolder(let relativePath):
        self?.showFolder(relativePath)
      case .loadPlayer(let relativePath):
        self?.loadPlayer(relativePath)
      case .showDocumentPicker:
        self?.showDocumentPicker()
      case .showSearchList(let relativePath, let placeholderTitle):
        self?.showSearchList(at: relativePath, placeholderTitle: placeholderTitle)
      case .showItemDetails(let item):
        self?.showItemDetails(item)
      case .showExportController(let items):
        self?.showExportController(for: items)
      case .showItemSelectionScreen(let availableItems, let selectionHandler):
        self?.showItemSelectionScreen(availableItems: availableItems, selectionHandler: selectionHandler)
      case .showMiniPlayer(let flag):
        self?.showMiniPlayer(flag: flag)
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

    self.presentingViewController = self.navigationController
    self.navigationController.pushViewController(vc, animated: true)
    self.navigationController.delegate = self

    if let tabBarController = tabBarController {
      let newControllersArray = (tabBarController.viewControllers ?? []) + [self.navigationController]
      tabBarController.setViewControllers(newControllersArray, animated: false)
    }

    self.loadLastBookIfNeeded()

    if let appDelegate = AppDelegate.shared {
      for action in appDelegate.pendingURLActions {
        ActionParserService.handleAction(action)
      }
    }

    self.documentPickerDelegate = vc

    AppDelegate.shared?.watchConnectivityService?.startSession()
    syncList()
  }

  func bindImportObserver() {
    self.fileSubscription?.cancel()
    self.importOperationSubscription?.cancel()

    self.fileSubscription = self.importManager.observeFiles().sink { [weak self] files in
      guard let self = self,
            !files.isEmpty,
            self.shouldShowImportScreen() else { return }

      self.showImport()
    }

    self.importOperationSubscription = self.importManager.operationPublisher.sink(receiveValue: { [weak self] operation in
      guard let self = self else {
        return
      }

      let coordinator = self.getLastItemListCoordinator(from: self)

      coordinator.onAction?(.newImportOperation(operation))

      operation.completionBlock = {
        DispatchQueue.main.async {
          coordinator.onAction?(.importOperationFinished(operation.processedFiles))
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

        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.showPlayer.rawValue) {
          UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.showPlayer.rawValue)
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
    let child = ImportCoordinator(
      importManager: self.importManager,
      presentingViewController: self.presentingViewController
    )
    child.parentCoordinator = self
    self.childCoordinators.append(child)
    child.start()
  }

  func shouldShowImportScreen() -> Bool {
    return !self.childCoordinators.contains(where: { $0 is ImportCoordinator })
  }

  func getLastItemListCoordinator(from coordinator: ItemListCoordinator) -> ItemListCoordinator {
    if let child = coordinator.childCoordinators.last(where: { $0 is ItemListCoordinator}) as? ItemListCoordinator {
      return getLastItemListCoordinator(from: child)
    } else {
      return coordinator
    }
  }

  override func interactiveDidFinish(vc: UIViewController) {
    // Coordinator may be already released if popped by VoiceOver gesture
    guard let vc = vc as? ItemListViewController,
          vc.viewModel.coordinator != nil else { return }

    vc.viewModel.coordinator.detach()
  }

  func syncLibrary() {
    Task { [weak self] in
      guard
        let (newItems, lastPlayed) = try await self?.syncService.syncLibraryContents()
      else { return }

      self?.processFetchedItems(newItems, lastPlayed: lastPlayed)
    }
  }

  override func syncList() {
    Task { [weak self] in
      guard
        let self = self
      else { return }

      guard let (newItems, lastPlayed) = try await self.syncService.syncListContents(at: nil) else { return }

      self.processFetchedItems(newItems, lastPlayed: lastPlayed)
    }
  }

  func processFetchedItems(_ items: [SyncableItem], lastPlayed: SyncableItem?) {
    reloadItemsWithPadding(padding: items.count)

    guard let lastPlayedRelativePath = lastPlayed?.relativePath else { return }

    let lastItemRelativePath = libraryService.getLibraryLastItem()?.relativePath

    guard lastItemRelativePath != lastPlayedRelativePath else { return }

    playerManager.stop()
    libraryService.setLibraryLastBook(with: lastPlayedRelativePath)

    guard
      let lastItem = libraryService.getLibraryLastItem(),
      let playableItem = try? playbackService.getPlayableItem(from: lastItem)
    else { return }

    playerManager.currentItem = playableItem
  }
}
