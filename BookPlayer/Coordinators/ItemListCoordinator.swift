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

public typealias Transition<T> = ((T) -> Void)
enum ItemListActionRoutes {
  case importOptions
  case importLocalFiles
  case createFolder(_ title: String, items: [LibraryItem]?)
  case newImportOperation(_ operation: ImportOperation)
  case importOperationFinished(_ urls: [URL])
  case insertIntoLibrary(_ items: [LibraryItem])
}

class ItemListCoordinator: Coordinator {
  public var onTransition: Transition<ItemListActionRoutes>?
  let miniPlayerOffset: CGFloat
  let playerManager: PlayerManager
  let importManager: ImportManager
  let library: Library

  var fileSubscription: AnyCancellable?
  var importOperationSubscription: AnyCancellable?

  init(
    navigationController: UINavigationController,
    library: Library,
    miniPlayerOffset: CGFloat,
    playerManager: PlayerManager,
    importManager: ImportManager
  ) {
    self.library = library
    self.miniPlayerOffset = miniPlayerOffset
    self.playerManager = playerManager
    self.importManager = importManager

    super.init(navigationController: navigationController)

    self.bindImportObserver()
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
      guard let self = self,
            self.shouldHandleImport() else {
        return
      }

      self.onTransition?(.newImportOperation(operation))

      operation.completionBlock = {
        DispatchQueue.main.async {
          self.onTransition?(.importOperationFinished(operation.processedFiles))
        }
      }

      DataManager.start(operation)
    })
  }

  override func start() {
    fatalError("ItemListCoordinator is an abstract class, override this function in the subclass")
  }

  func getMainCoordinator() -> MainCoordinator? {
    switch self.parentCoordinator {
    case let mainCoordinator as MainCoordinator:
      return mainCoordinator
    case let listCoordinator as ItemListCoordinator:
      return listCoordinator.getMainCoordinator()
    default:
      return nil
    }
  }

  func showItemContents(_ item: LibraryItem) {
    switch item {
    case let folder as Folder:
      self.showFolder(folder)
    case let book as Book:
      self.loadPlayer(book)
    default:
      break
    }
  }

  func showFolder(_ folder: Folder) {
    let child = FolderListCoordinator(navigationController: self.navigationController,
                                      library: self.library,
                                      folder: folder,
                                      playerManager: self.playerManager,
                                      importManager: self.importManager,
                                      miniPlayerOffset: self.miniPlayerOffset)
    self.childCoordinators.append(child)
    child.parentCoordinator = self
    child.start()
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      navigationController: self.navigationController,
      playerManager: self.playerManager
    )
    playerCoordinator.parentCoordinator = self
    self.childCoordinators.append(playerCoordinator)
    playerCoordinator.start()
  }

  func loadPlayer(_ book: Book) {
    guard DataManager.exists(book) else {
      self.navigationController.showAlert("file_missing_title".localized, message: "\("file_missing_description".localized)\n\(book.originalFileName ?? "")")
      return
    }

    self.showPlayer()

    // Only load if loaded book is a different one
    guard book.relativePath != playerManager.currentBook?.relativePath else { return }

    self.playerManager.load(book) { [weak self] loaded in
      guard loaded else { return }

      self?.playerManager.playPause()
    }
  }

  func loadLastBook(_ book: Book) {
    self.playerManager.load(book) { [weak self] loaded in
      guard loaded else { return }

      if UserDefaults.standard.bool(forKey: Constants.UserActivityPlayback) {
        UserDefaults.standard.removeObject(forKey: Constants.UserActivityPlayback)
        self?.playerManager.play()
      }

      if UserDefaults.standard.bool(forKey: Constants.UserDefaults.showPlayer.rawValue) {
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.showPlayer.rawValue)
        self?.showPlayer()
      }
    }
  }

  func showImport() {
    let child = ImportCoordinator(
      navigationController: self.navigationController,
      importManager: self.importManager
    )
    self.childCoordinators.append(child)
    child.parentCoordinator = self
    child.presentingViewController = self.presentingViewController
    child.start()
  }

  private func shouldShowImportScreen() -> Bool {
    return !self.childCoordinators.contains(where: { $0 is ItemListCoordinator || $0 is ImportCoordinator })
  }

  private func shouldHandleImport() -> Bool {
    return !self.childCoordinators.contains(where: { $0 is ItemListCoordinator })
  }

  func showOperationCompletedAlert(with items: [LibraryItem]) {
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

      self.showCreatePlaylistAlert(placeholder: placeholder, with: items)
    })

    self.navigationController.present(alert, animated: true, completion: nil)
  }
}

extension ItemListCoordinator {
  func showCreatePlaylistAlert(placeholder: String? = nil, with items: [LibraryItem]? = nil) {
    let alert = UIAlertController(title: "create_playlist_title".localized,
                                  message: "create_playlist_description".localized,
                                  preferredStyle: .alert)

    alert.addTextField(configurationHandler: { textfield in
      textfield.text = placeholder ?? "new_playlist_button".localized
    })

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "create_button".localized, style: .default, handler: { _ in
      let title = alert.textFields!.first!.text!

      self.onTransition?(.createFolder(title, items: items))
    }))

    self.navigationController.present(alert, animated: true, completion: nil)
  }

  func showAddActions() {
    let alertController = UIAlertController(title: nil,
                                            message: "import_description".localized,
                                            preferredStyle: .actionSheet)

    alertController.addAction(UIAlertAction(title: "import_button".localized, style: .default) { _ in
      self.onTransition?(.importLocalFiles)
    })

    alertController.addAction(UIAlertAction(title: "create_playlist_button".localized, style: .default) { _ in
      self.showCreatePlaylistAlert()
    })

    alertController.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel))

    self.navigationController.present(alertController, animated: true, completion: nil)
  }

  func showDocumentPicker(in vc: UIViewController) {
    let providerList = UIDocumentPickerViewController(documentTypes: ["public.audio", "com.pkware.zip-archive", "public.movie"], in: .import)

    providerList.delegate = vc as? UIDocumentPickerDelegate
    providerList.allowsMultipleSelection = true

    UIApplication.shared.isIdleTimerDisabled = true

    vc.present(providerList, animated: true, completion: nil)
  }
}
