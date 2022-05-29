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

  init(
    navigationController: UINavigationController,
    playerManager: PlayerManagerProtocol,
    importManager: ImportManager,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol
  ) {
    self.importManager = importManager

    super.init(
      navigationController: navigationController,
      playerManager: playerManager,
      libraryService: libraryService,
      playbackService: playbackService
    )

    self.bindImportObserver()
  }

  override func start() {
    let vc = ItemListViewController.instantiate(from: .Main)
    let viewModel = ItemListViewModel(folderRelativePath: nil,
                                      playerManager: self.playerManager,
                                      libraryService: self.libraryService,
                                      themeAccent: ThemeManager.shared.currentTheme.linkColor)
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

    self.loadLastBookIfAvailable()

    if let appDelegate = AppDelegate.shared {
      for action in appDelegate.pendingURLActions {
        ActionParserService.handleAction(action)
      }
    }

    self.documentPickerDelegate = vc
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
}
