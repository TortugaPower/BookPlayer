//
//  LibraryViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/7/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import MediaPlayer
import SwiftReorder
import UIKit

// swiftlint:disable file_length

class LibraryViewController: ItemListViewController, UIGestureRecognizerDelegate {
    private var fileSubscription: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = "library_title".localized
        self.navigationItem.leftBarButtonItem?.title = "settings_button".localized

        // VoiceOver
        self.setupCustomRotors()

        // enables pop gesture on pushed controller
        self.navigationController!.interactivePopGestureRecognizer!.delegate = self

        self.loadLibrary()

        self.loadLastBook()

        self.sendSignal(.libraryScreen, with: nil)
    }

    // No longer need to deregister observers for iOS 9+!
    // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11NotificationCenter
    deinit {
        // for iOS 8
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    override func setupObservers() {
        super.setupObservers()
        // register for appDelegate openUrl notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: .reloadData, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onProcessingFile(_:)), name: .processingFile, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onNewFileUrl), name: .newFileUrl, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onNewOperation(_:)), name: .importOperation, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onDownloadingProgress(_:)), name: .downloadProgress, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bindImportManager), name: .importOperationCancelled, object: nil)
        self.bindImportManager()
    }

  @objc func bindImportManager() {
    self.fileSubscription?.cancel()
    self.fileSubscription = ImportManager.shared.observeFiles().sink { [weak self] files in
      guard let self = self,
            !files.isEmpty else { return }

      self.showImport()
    }
  }

  func showImport() {
    self.fileSubscription?.cancel()
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let vc = storyboard.instantiateViewController(withIdentifier: "ImportViewController")
    let nav = UINavigationController(rootViewController: vc)

    self.present(nav, animated: true, completion: nil)
  }

    func loadLibrary() {
        self.library = DataManager.getLibrary()

        self.toggleEmptyStateView()

        self.tableView.reloadData()

        DataManager.notifyPendingFiles()
    }

    func downloadBook(from urlString: String) {
        guard let url = URL(string: urlString) else {
            self.showAlert("error_title".localized, message: String.localizedStringWithFormat("invalid_url_title".localized, urlString))
            return
        }

        self.showLoadView(true, title: "downloading_file_title".localized, subtitle: "\("progress_title".localized) 0%")

        NetworkService.shared.download(from: url) { response in
            self.showLoadView(false)

            if response.error != nil,
                let error = response.error {
                self.showAlert("network_error_title".localized, message: error.localizedDescription)
            }

            if let response = response.response, response.statusCode >= 300 {
                self.showAlert("network_error_title".localized, message: "Code \(response.statusCode)")
            }
        }
    }

    func loadLastBook() {
        guard let book = self.library.lastPlayedBook else {
            return
        }

        // Preload player
        PlayerManager.shared.load(book) { loaded in
            guard loaded else { return }

            NotificationCenter.default.post(name: .playerDismissed, object: nil, userInfo: nil)
            if UserDefaults.standard.bool(forKey: Constants.UserActivityPlayback) {
                UserDefaults.standard.removeObject(forKey: Constants.UserActivityPlayback)
                PlayerManager.shared.play()
            }

            if UserDefaults.standard.bool(forKey: Constants.UserDefaults.showPlayer.rawValue) {
                UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.showPlayer.rawValue)
                self.showPlayerView(book: book)
            }
        }
    }

    override func handleOperationCompletion(_ files: [URL]) {
      self.bindImportManager()

      let processedItems = DataManager.insertItems(from: files, into: nil, library: self.library)
      self.reloadData()

      guard files.count > 1 else {
        self.showLoadView(false)
        return
      }

      let alert = UIAlertController(title: String.localizedStringWithFormat("import_alert_title".localized, files.count), message: nil, preferredStyle: .alert)

      alert.addAction(UIAlertAction(title: "library_title".localized, style: .default) { _ in
        self.showLoadView(false)
      })

      alert.addAction(UIAlertAction(title: "new_playlist_button".localized, style: .default) { _ in
        var placeholder = "new_playlist_button".localized

        if let file = files.first {
          placeholder = file.deletingPathExtension().lastPathComponent
        }

        self.presentCreateFolderAlert(placeholder, handler: { title in
          do {
            let folder = try DataManager.createFolder(with: title, in: nil, library: self.library)
            try DataManager.moveItems(processedItems, into: folder)
          } catch {
            self.showAlert("error_title".localized, message: error.localizedDescription)
          }

          self.reloadData()
          self.showLoadView(false)
        })
      })

      let vc = self.presentedViewController ?? self

      vc.present(alert, animated: true, completion: nil)
    }

    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        return navigationController!.viewControllers.count > 1
    }

    // MARK: - Callback events

    // This is called from a background thread inside an ImportOperation
    @objc func onDownloadingProgress(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let progress = userInfo["progress"] as? String else {
            return
        }

        DispatchQueue.main.async {
            self.showLoadView(true, title: "downloading_file_title".localized, subtitle: "\("progress_title".localized) \(progress)%")

            if let vc = self.navigationController?.visibleViewController as? PlaylistViewController {
                vc.showLoadView(true, title: "downloading_file_title".localized, subtitle: "\("progress_title".localized) \(progress)%")
            }
        }
    }

    @objc func onNewFileUrl() {
        guard self.loadingView.isHidden else { return }
        let loadingTitle = "import_preparing_title".localized
        UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: self.loadingView.titleLabel)

        if let vc = self.navigationController?.visibleViewController as? PlayerViewController {
            vc.dismissPlayer()
        }

        self.showLoadView(true, title: loadingTitle)

        if let vc = self.navigationController?.visibleViewController as? PlaylistViewController {
            vc.showLoadView(true, title: loadingTitle)
        }
    }

    // This is called from a background thread inside an ImportOperation
    @objc func onProcessingFile(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let filename = userInfo["filename"] as? String else {
            return
        }

        DispatchQueue.main.async {
            self.showLoadView(true, title: nil, subtitle: filename)

            if let vc = self.navigationController?.visibleViewController as? PlaylistViewController {
                vc.showLoadView(true, title: nil, subtitle: filename)
            }
        }
    }

    @objc func onNewOperation(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let operation = userInfo["operation"] as? ImportOperation
        else {
            return
        }

        let loadingTitle = String.localizedStringWithFormat("import_processing_description".localized, operation.files.count)

        self.showLoadView(true, title: loadingTitle)

        if let vc = self.navigationController?.visibleViewController as? PlaylistViewController {
            vc.showLoadView(true, title: loadingTitle)
        }

        operation.completionBlock = {
            DispatchQueue.main.async {
              guard let vc = self.navigationController?.visibleViewController as? PlaylistViewController else {
                self.handleOperationCompletion(operation.processedFiles)
                return
              }
              self.showLoadView(false)
              vc.handleOperationCompletion(operation.processedFiles)
              self.bindImportManager()
            }
        }

        DataManager.start(operation)
        self.sendSignal(.importAction, with: operation.getInfo())
    }

    // MARK: - IBActions

    @IBAction func addAction() {
        self.presentAddOptionsAlert()
    }

    // Sorting
    override func sort(by sortType: PlayListSortOrder) {
        library.sort(by: sortType)
    }

    override func presentAddOptionsAlert() {
        let alertController = UIAlertController(title: nil,
                                                message: "import_description".localized,
                                                preferredStyle: .actionSheet)

        alertController.addAction(UIAlertAction(title: "import_button".localized, style: .default) { _ in
            self.presentImportFilesAlert()
        })

        alertController.addAction(UIAlertAction(title: "create_playlist_button".localized, style: .default) { _ in
            self.presentCreateFolderAlert(handler: { title in
              do {
                _ = try DataManager.createFolder(with: title, in: nil, library: self.library)
              } catch {
                self.showAlert("error_title".localized, message: error.localizedDescription)
              }

              self.reloadData()
            })
        })

        alertController.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel))

        present(alertController, animated: true, completion: nil)
    }

    override func handleMove(_ selectedItems: [LibraryItem]) {
        let alert = UIAlertController(title: "choose_destination_title".localized, message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "new_playlist_button".localized, style: .default) { _ in
            self.presentCreateFolderAlert(handler: { title in
              do {
                let folder = try DataManager.createFolder(with: title, in: nil, library: self.library)
                try self.move(selectedItems, to: folder)
              } catch {
                self.showAlert("error_title".localized, message: error.localizedDescription)
              }
            })
        })

        let availableFolders = self.items.compactMap { (item) -> Folder? in
            item as? Folder
        }

        let existingFolderAction = UIAlertAction(title: "existing_playlist_button".localized, style: .default) { _ in

            let vc = ItemSelectionViewController()
            vc.items = availableFolders

            vc.onItemSelected = { selectedItem in
              guard let selectedFolder = selectedItem as? Folder else { return }

              do {
                try self.move(selectedItems, to: selectedFolder)
              } catch {
                self.showAlert("error_title".localized, message: error.localizedDescription)
              }
            }

            let nav = AppNavigationController(rootViewController: vc)
            self.present(nav, animated: true, completion: nil)
        }

        existingFolderAction.isEnabled = !availableFolders.isEmpty
        alert.addAction(existingFolderAction)

        alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel))

        self.present(alert, animated: true, completion: nil)
    }

    override func handleTrash(_ selectedItems: [LibraryItem]) {
        self.handleDelete(items: selectedItems)
    }
}

// MARK: Accessibility

extension LibraryViewController {
    private func setupCustomRotors() {
        accessibilityCustomRotors = [self.rotorFactory(name: "Books", type: .book), self.rotorFactory(name: "Folders", type: .folder)]
    }

    private func rotorFactory(name: String, type: BookCellType) -> UIAccessibilityCustomRotor {
        return UIAccessibilityCustomRotor(name: name) { (predicate) -> UIAccessibilityCustomRotorItemResult? in
            let forward: Bool = (predicate.searchDirection == .next)

            let playListCells = self.tableView.visibleCells.filter { (cell) -> Bool in
                guard let cell = cell as? BookCellView else { return false }
                return cell.type == type
            }

            var currentIndex = forward ? -1 : playListCells.count
            //
            if let currentElement = predicate.currentItem.targetElement {
                if let cell = currentElement as? BookCellView {
                    currentIndex = playListCells.firstIndex(of: cell) ?? currentIndex
                }
            }
            let nextIndex = forward ? currentIndex + 1 : currentIndex - 1

            while nextIndex >= 0, nextIndex < playListCells.count {
                let cell = playListCells[nextIndex]
                return UIAccessibilityCustomRotorItemResult(targetElement: cell, targetRange: nil)
            }
            return nil
        }
    }
}

// MARK: - TableView Delegate

extension LibraryViewController {
    func tableView(_: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.sectionValue == .data else { return nil }

        let item = items[indexPath.row]

        let optionsAction = UITableViewRowAction(style: .normal, title: "\("options_button".localized)…") { _, _ in
            guard let sheet = self.createOptionsSheetController([item]) else { return }

            // "…" on a button indicates a follow up dialog instead of an immmediate action in macOS and iOS
            var title = "\("delete_button".localized)…"

            // Remove the dots if trying to delete an empty folder
            if let folder = item as? Folder {
                title = folder.hasBooks() ? title : "delete_button".localized
            }

            let deleteAction = UIAlertAction(title: title, style: .destructive) { _ in
                guard let book = self.items[indexPath.row] as? Book else {
                    guard let folder = self.items[indexPath.row] as? Folder else { return }

                    guard folder.hasBooks() else {
                      do {
                        try DataManager.delete([folder], library: self.library)
                        self.deleteRows(at: [indexPath])
                      } catch {
                        self.showAlert("error_title".localized, message: error.localizedDescription)
                      }

                      return
                    }

                    self.handleDelete(items: [folder])

                    return
                }

                self.handleDelete(items: [book])
            }

            sheet.addAction(deleteAction)

            self.present(sheet, animated: true, completion: nil)
        }

        return [optionsAction]
    }
}

// MARK: - TableView DataSource

extension LibraryViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        guard let bookCell = cell as? BookCellView,
            let currentBook = PlayerManager.shared.currentBook,
            let index = self.library.index(for: currentBook),
            index == indexPath.row else {
            return cell
        }

        bookCell.playbackState = .paused

        return bookCell
    }
}

// MARK: - Reorder Delegate

extension LibraryViewController {
    override func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        super.tableView(tableView, reorderRowAt: sourceIndexPath, to: destinationIndexPath)

        guard destinationIndexPath.sectionValue == .data else {
            return
        }

        let item = self.items[sourceIndexPath.row]

        self.library.removeFromItems(at: sourceIndexPath.row)
        self.library.insertIntoItems(item, at: destinationIndexPath.row)

        DataManager.saveContext()
    }

    override func tableViewDidFinishReordering(_ tableView: UITableView, from initialSourceIndexPath: IndexPath, to finalDestinationIndexPath: IndexPath, dropped overIndexPath: IndexPath?) {
        super.tableViewDidFinishReordering(tableView, from: initialSourceIndexPath, to: finalDestinationIndexPath, dropped: overIndexPath)

        guard let overIndexPath = overIndexPath, overIndexPath.sectionValue == .data else { return }

        let sourceItem = self.items[finalDestinationIndexPath.row]
        let destinationItem = self.items[overIndexPath.row]

        guard let folder = destinationItem as? Folder ?? sourceItem as? Folder else {
            let minIndex = min(finalDestinationIndexPath.row, overIndexPath.row)

            self.presentCreateFolderAlert(destinationItem.title, handler: { title in
              do {
                let folder = try DataManager.createFolder(with: title, in: nil, library: self.library, at: minIndex)
                try self.move([sourceItem, destinationItem], to: folder)
              } catch {
                self.showAlert("error_title".localized, message: error.localizedDescription)
              }

              self.reloadData()
            })
            return
        }

        let selectedItem = folder == destinationItem
            ? sourceItem
            : destinationItem

        let message = String.localizedStringWithFormat("move_single_item_title".localized, selectedItem.title!, folder.title!)

        let alert = UIAlertController(title: "move_playlist_button".localized,
                                      message: message,
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

        alert.addAction(UIAlertAction(title: "move_title".localized, style: .default, handler: { _ in
          do {
            try self.move([selectedItem], to: folder)
          } catch {
            self.showAlert("error_title".localized, message: error.localizedDescription)
          }

          self.reloadData()
        }))

        self.present(alert, animated: true, completion: nil)
    }
}
