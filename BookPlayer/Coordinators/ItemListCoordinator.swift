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

enum ItemListActionRoutes {
  case importOptions
  case importIntoFolder(_ folder: SimpleLibraryItem, items: [LibraryItem], type: SimpleItemType)
  case downloadBook(_ url: URL)
  case createFolder(_ title: String, items: [String]?, type: SimpleItemType)
  case updateFolders(_ folders: [SimpleLibraryItem], type: SimpleItemType)
  case moveIntoLibrary(items: [SimpleLibraryItem])
  case moveIntoFolder(_ folder: SimpleLibraryItem, items: [SimpleLibraryItem])
  case delete(_ items: [SimpleLibraryItem], mode: DeleteMode)
  case resetPlaybackPosition(_ items: [SimpleLibraryItem])
  case markAsFinished(_ items: [SimpleLibraryItem], flag: Bool)
  case newImportOperation(_ operation: ImportOperation)
  case importOperationFinished(_ urls: [URL])
  case insertIntoLibrary(_ items: [LibraryItem])
  case sortItems(_ option: SortType)
  case reloadItems(_ pageSizePadding: Int)
}

class ItemListCoordinator: Coordinator {
  public var onAction: Transition<ItemListActionRoutes>?
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let syncService: SyncServiceProtocol

  weak var documentPickerDelegate: UIDocumentPickerDelegate?

  init(
    navigationController: UINavigationController,
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.syncService = syncService

    super.init(navigationController: navigationController,
               flowType: .push)
  }

  override func start() {
    fatalError("ItemListCoordinator is an abstract class, override this function in the subclass")
  }

  override func getMainCoordinator() -> MainCoordinator? {
    switch self.parentCoordinator {
    case let mainCoordinator as MainCoordinator:
      return mainCoordinator
    case let listCoordinator as ItemListCoordinator:
      return listCoordinator.getMainCoordinator()
    default:
      return nil
    }
  }

  func showFolder(_ relativePath: String) {
    let child = FolderListCoordinator(
      navigationController: navigationController,
      folderRelativePath: relativePath,
      playerManager: playerManager,
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService
    )
    self.childCoordinators.append(child)
    child.parentCoordinator = self
    child.start()
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      presentingViewController: self.navigationController
    )
    playerCoordinator.parentCoordinator = self
    self.childCoordinators.append(playerCoordinator)
    playerCoordinator.start()
  }

  func showSearchList(at relativePath: String?, placeholderTitle: String) {
    let coordinator = SearchListCoordinator(
      navigationController: navigationController,
      placeholderTitle: placeholderTitle,
      folderRelativePath: relativePath,
      playerManager: playerManager,
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService
    )
    coordinator.start()
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

  func loadLastBookIfAvailable() {
    guard let libraryItem = try? self.libraryService.getLibraryLastItem() else { return }

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

  func showOperationCompletedAlert(with items: [LibraryItem], availableFolders: [SimpleLibraryItem]) {
    let alert = UIAlertController(
      title: String.localizedStringWithFormat("import_alert_title".localized, items.count),
      message: nil,
      preferredStyle: .alert)

    alert.addAction(UIAlertAction(title: "library_title".localized, style: .default, handler: nil))

    alert.addAction(UIAlertAction(title: "new_playlist_button".localized, style: .default) { _ in
      var placeholder = "new_playlist_button".localized

      if let item = items.first {
        placeholder = item.title
      }

      let itemPaths = items.map { $0.relativePath! }
      self.showCreateFolderAlert(placeholder: placeholder, with: itemPaths, type: .folder)
    })

    let existingFolderAction = UIAlertAction(title: "existing_playlist_button".localized, style: .default) { _ in
      let vc = ItemSelectionViewController()
      vc.items = availableFolders

      vc.onItemSelected = { selectedFolder in
        self.onAction?(.importIntoFolder(selectedFolder, items: items, type: .folder))
      }

      let nav = AppNavigationController(rootViewController: vc)
      self.navigationController.present(nav, animated: true, completion: nil)
    }

    existingFolderAction.isEnabled = !availableFolders.isEmpty
    alert.addAction(existingFolderAction)

    let convertAction = UIAlertAction(title: "bound_books_create_button".localized, style: .default) { _ in
      var placeholder = "bound_books_new_title_placeholder".localized

      if let item = items.first {
        placeholder = item.title
      }

      let itemPaths = items.map { $0.relativePath! }
      self.showCreateFolderAlert(placeholder: placeholder, with: itemPaths, type: .bound)
    }
    convertAction.isEnabled = items is [Book]
    alert.addAction(convertAction)

    self.navigationController.present(alert, animated: true, completion: nil)
  }

  func syncList() {
    fatalError("ItemListCoordinator is an abstract class, override this function in the subclass")
  }
}

extension ItemListCoordinator {
  func showCreateFolderAlert(placeholder: String? = nil,
                             with items: [String]? = nil,
                             type: SimpleItemType = .folder) {
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

    let alert = UIAlertController(title: alertTitle,
                                  message: alertMessage,
                                  preferredStyle: .alert)

    alert.addTextField(configurationHandler: { textfield in
      textfield.text = placeholder ?? alertPlaceholderDefault
    })

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "create_button".localized, style: .default, handler: { _ in
      let title = alert.textFields!.first!.text!
      self.onAction?(.createFolder(title, items: items, type: type))
    }))

    self.navigationController.present(alert, animated: true, completion: nil)
  }

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

    self.presentingViewController?.present(providerList, animated: true, completion: nil)
  }

  func showSortOptions() {
    let alert = UIAlertController(title: "sort_files_title".localized, message: nil, preferredStyle: .actionSheet)

    alert.addAction(UIAlertAction(title: "title_button".localized, style: .default, handler: { _ in
      self.onAction?(.sortItems(.metadataTitle))
    }))

    alert.addAction(UIAlertAction(title: "sort_filename_button".localized, style: .default, handler: { _ in
      self.onAction?(.sortItems(.fileName))
    }))

    alert.addAction(UIAlertAction(title: "sort_most_recent_button".localized, style: .default, handler: { _ in
      self.onAction?(.sortItems(.mostRecent))
    }))

    alert.addAction(UIAlertAction(title: "sort_reversed_button".localized, style: .default, handler: { _ in
      self.onAction?(.sortItems(.reverseOrder))
    }))

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

    self.navigationController.present(alert, animated: true, completion: nil)
  }

  func showMoveOptions(selectedItems: [SimpleLibraryItem], availableFolders: [SimpleLibraryItem]) {
    let alert = UIAlertController(title: "choose_destination_title".localized, message: nil, preferredStyle: .alert)

    if self is FolderListCoordinator {
      alert.addAction(UIAlertAction(title: "library_title".localized, style: .default) { [weak self] _ in
        self?.onAction?(.moveIntoLibrary(items: selectedItems))
      })
    }

    alert.addAction(UIAlertAction(title: "new_playlist_button".localized, style: .default) { _ in
      self.showCreateFolderAlert(placeholder: selectedItems.first?.title, with: selectedItems.map { $0.relativePath })
    })

    let existingFolderAction = UIAlertAction(title: "existing_playlist_button".localized, style: .default) { _ in
      let vc = ItemSelectionViewController()
      vc.items = availableFolders

      vc.onItemSelected = { selectedFolder in
        self.onAction?(.moveIntoFolder(selectedFolder, items: selectedItems))
      }

      let nav = AppNavigationController(rootViewController: vc)
      self.navigationController.present(nav, animated: true, completion: nil)
    }

    existingFolderAction.isEnabled = !availableFolders.isEmpty
    alert.addAction(existingFolderAction)

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel))

    self.navigationController.present(alert, animated: true, completion: nil)
  }

  func showDeleteAlert(selectedItems: [SimpleLibraryItem]) {
    let alertTitle: String
    let alertMessage: String?

    if selectedItems.count == 1,
       let item = selectedItems.first {
      alertTitle = String(format: "delete_single_item_title".localized, item.title)
      alertMessage = nil
    } else {
      alertTitle = String.localizedStringWithFormat("delete_multiple_items_title".localized, selectedItems.count)
      alertMessage = "delete_multiple_items_description".localized
    }

    let alert = UIAlertController(title: alertTitle,
                                  message: alertMessage,
                                  preferredStyle: .alert)

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

    var deleteActionTitle = "delete_button".localized

    if selectedItems.count == 1,
       let item = selectedItems.first,
       item.type == .folder {
        deleteActionTitle = "delete_deep_button".localized

        alert.title = String(format: "delete_single_item_title".localized, item.title)
        alert.message = "delete_single_playlist_description".localized
        alert.addAction(UIAlertAction(title: "delete_shallow_button".localized, style: .default, handler: { _ in
          self.onAction?(.delete(selectedItems, mode: .shallow))
        }))
    }

    alert.addAction(UIAlertAction(title: deleteActionTitle, style: .destructive, handler: { _ in
      if selectedItems.contains(where: { $0.relativePath == self.playerManager.currentItem?.relativePath }) {
        self.playerManager.stop()
      }

      self.onAction?(.delete(selectedItems, mode: .deep))
    }))

    self.navigationController.present(alert, animated: true, completion: nil)
  }

  func showMoreOptionsAlert(selectedItems: [SimpleLibraryItem], availableFolders: [SimpleLibraryItem]) {
    guard let item = selectedItems.first else {
      return
    }

    let isSingle = selectedItems.count == 1

    let sheetTitle = isSingle ? item.title : "options_button".localized

    let sheet = UIAlertController(title: sheetTitle, message: nil, preferredStyle: .actionSheet)

    let detailsAction = UIAlertAction(title: "Details", style: .default) { [weak self] _ in
      self?.showItemDetails(item)
    }

    detailsAction.isEnabled = isSingle
    sheet.addAction(detailsAction)

    sheet.addAction(UIAlertAction(title: "move_title".localized, style: .default, handler: { _ in
      self.showMoveOptions(selectedItems: selectedItems, availableFolders: availableFolders)
    }))

    sheet.addAction(UIAlertAction(title: "export_button".localized, style: .default, handler: { _ in
      self.showExportController(for: selectedItems)
    }))

    sheet.addAction(UIAlertAction(title: "jump_start_title".localized, style: .default, handler: { [weak self] _ in
      self?.onAction?(.resetPlaybackPosition(selectedItems))
    }))

    let areFinished = selectedItems.filter({ !$0.isFinished }).isEmpty
    let markTitle = areFinished ? "mark_unfinished_title".localized : "mark_finished_title".localized

    sheet.addAction(UIAlertAction(title: markTitle, style: .default, handler: { [weak self] _ in
      self?.onAction?(.markAsFinished(selectedItems, flag: !areFinished))
    }))

    let boundBookAction: UIAlertAction

    if selectedItems.allSatisfy({ $0.type == .bound }) {
      boundBookAction = UIAlertAction(title: "bound_books_undo_alert_title".localized, style: .default, handler: { [weak self] _ in
        self?.onAction?(.updateFolders(selectedItems, type: .folder))
      })
      boundBookAction.isEnabled = true
    } else {
      boundBookAction = UIAlertAction(title: "bound_books_create_button".localized, style: .default, handler: { [weak self] _ in
        if isSingle {
          self?.onAction?(.updateFolders(selectedItems, type: .bound))
        } else {
          self?.showCreateFolderAlert(
            placeholder: item.title,
            with: selectedItems.map { $0.relativePath },
            type: .bound
          )
        }
      })
      boundBookAction.isEnabled = selectedItems.allSatisfy({ $0.type == .book }) || (isSingle && item.type == .folder)
    }

    sheet.addAction(boundBookAction)

    sheet.addAction(UIAlertAction(title: "\("delete_button".localized)", style: .destructive) { _ in
      self.showDeleteAlert(selectedItems: selectedItems)
    })

    sheet.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

    self.navigationController.present(sheet, animated: true, completion: nil)
  }

  func showExportController(for items: [SimpleLibraryItem]) {
    let providers = items.map { BookActivityItemProvider($0) }

    let shareController = UIActivityViewController(activityItems: providers, applicationActivities: nil)
    shareController.excludedActivityTypes = [.copyToPasteboard]

    self.navigationController.present(shareController, animated: true, completion: nil)
  }

  func reloadItemsWithPadding(padding: Int = 0) {
    // Reload all preceding screens too
    if let coordinator = self.parentCoordinator as? ItemListCoordinator {
      coordinator.reloadItemsWithPadding(padding: padding)
    }

    self.onAction?(.reloadItems(padding))
  }

  func showItemDetails(_ item: SimpleLibraryItem) {
    let coordinator = ItemDetailsCoordinator(
      item: item,
      libraryService: libraryService,
      navigationController: navigationController
    )

    coordinator.onFinish = { route in
      switch route {
      case .infoUpdated:
        self.reloadItemsWithPadding()
      }
    }

    coordinator.start()
  }
}
