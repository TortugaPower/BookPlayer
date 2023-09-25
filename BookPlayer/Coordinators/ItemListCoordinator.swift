//
//  ItemListCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import UIKit
import UniformTypeIdentifiers

class ItemListCoordinator: NSObject, Coordinator, AlertPresenter, BPLogger {
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let syncService: SyncServiceProtocol
  let flow: BPCoordinatorPresentationFlow

  weak var documentPickerDelegate: UIDocumentPickerDelegate?

  init(
    flow: BPCoordinatorPresentationFlow,
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.flow = flow
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.syncService = syncService
  }

  func start() {
    fatalError("ItemListCoordinator is an abstract class, override this function in the subclass")
  }

  func getMainCoordinator() -> MainCoordinator? {
    return AppDelegate.shared?.activeSceneDelegate?.mainCoordinator
  }

  func showFolder(_ relativePath: String) {
    let child = FolderListCoordinator(
      flow: .pushFlow(navigationController: flow.navigationController),
      folderRelativePath: relativePath,
      playerManager: playerManager,
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService
    )
    child.start()
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      flow: .modalOnlyFlow(presentingController: flow.navigationController, modalPresentationStyle: .overFullScreen),
      playerManager: playerManager,
      libraryService: libraryService,
      syncService: syncService
    )
    playerCoordinator.start()
  }

  func showSearchList(at relativePath: String?, placeholderTitle: String) {
    let viewModel = SearchListViewModel(
      folderRelativePath: relativePath,
      placeholderTitle: placeholderTitle,
      libraryService: libraryService,
      syncService: syncService,
      playerManager: playerManager,
      themeAccent: ThemeManager.shared.currentTheme.linkColor
    )
    viewModel.onTransition = { route in
      switch route {
      case .showFolder(let relativePath):
        self.showFolder(relativePath)
      case .loadPlayer(let relativePath):
        self.loadPlayer(relativePath)
      }
    }
    let vc = SearchListViewController(viewModel: viewModel)

    flow.pushViewController(vc, animated: true)
  }

  func loadPlayer(_ relativePath: String) {
    AppDelegate.shared?.loadPlayer(
      relativePath,
      autoplay: true,
      showPlayer: { [weak self] in
        self?.showPlayer()
      },
      alertPresenter: self
    )
  }

  func showMiniPlayer(flag: Bool) {
    getMainCoordinator()?.showMiniPlayer(flag)
  }

  func syncList() {
    fatalError("ItemListCoordinator is an abstract class, override this function in the subclass")
  }
}

extension ItemListCoordinator {
  func showDocumentPicker() {
    let providerList = UIDocumentPickerViewController(
      forOpeningContentTypes: [
        UTType.audio,
        UTType.movie,
        UTType.zip,
        UTType.folder
      ],
      asCopy: true
    )

    providerList.delegate = self.documentPickerDelegate
    providerList.allowsMultipleSelection = true

    UIApplication.shared.isIdleTimerDisabled = true

    flow.navigationController.present(providerList, animated: true, completion: nil)
  }

  func showExportController(for items: [SimpleLibraryItem]) {
    let providers = items.map { BookActivityItemProvider($0) }

    let shareController = UIActivityViewController(activityItems: providers, applicationActivities: nil)
    shareController.excludedActivityTypes = [.copyToPasteboard]

    if let popoverPresentationController = shareController.popoverPresentationController,
       let view = flow.navigationController.topViewController?.view {
      popoverPresentationController.permittedArrowDirections = []
      popoverPresentationController.sourceView = view
      popoverPresentationController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
    }

    flow.navigationController.present(shareController, animated: true, completion: nil)
  }

  func reloadItemsWithPadding(padding: Int = 0) {
    // Reload all screens too
    for vc in flow.navigationController.viewControllers {
      guard let itemVC = vc as? ItemListViewController else { continue }
      itemVC.viewModel.reloadItems(pageSizePadding: padding)
    }
  }

  func showItemDetails(_ item: SimpleLibraryItem) {
    let viewModel = ItemDetailsViewModel(
      item: item,
      libraryService: libraryService,
      syncService: syncService
    )
    let vc = ItemDetailsViewController(viewModel: viewModel)
    viewModel.onTransition = { [vc] route in
      switch route {
      case .done:
        self.reloadItemsWithPadding()
      case .cancel:
        /// do nothing on cancel
        break
      }
      vc.dismiss(animated: true)
    }

    if UIAccessibility.isVoiceOverRunning {
      vc.navigationItem.largeTitleDisplayMode = .never
    }
    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]

    flow.navigationController.present(nav, animated: true, completion: nil)
  }

  func showItemSelectionScreen(
    availableItems: [SimpleLibraryItem],
    selectionHandler: @escaping (SimpleLibraryItem) -> Void
  ) {
    let vc = ItemSelectionViewController()
    vc.items = availableItems
    vc.onItemSelected = selectionHandler

    let nav = AppNavigationController(rootViewController: vc)
    flow.navigationController.present(nav, animated: true, completion: nil)
  }
}
