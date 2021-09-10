//
//  PlaylistViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import MediaPlayer
import UIKit

class PlaylistViewController: ItemListViewController {
    var folder: Folder!

    override var items: [LibraryItem] {
        return self.folder.items?.array as? [LibraryItem] ?? []
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.toggleEmptyStateView()

        self.navigationItem.title = self.folder.title
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let relativePath = currentBook.relativePath,
            let index = self.folder.itemIndex(with: relativePath) else {
            return
        }

      // Hack to enable scroll to current item
      DispatchQueue.main.async { [weak self] in
        self?.tableView.scrollToRow(at: IndexPath(row: index, section: .data), at: .middle, animated: false)
      }
    }

    override func reloadData() {
        super.reloadData()
        NotificationCenter.default.post(name: .reloadData, object: nil)
    }

    override func handleOperationCompletion(_ files: [URL]) {
      let processedItems = DataManager.insertItems(from: files, into: nil, library: self.library)

      do {
        try DataManager.moveItems(processedItems, into: self.folder)
        self.reloadData()
      } catch {
        self.showAlert("error_title".localized, message: error.localizedDescription)
        return
      }

        guard files.count > 1 else {
            self.showLoadView(false)
            NotificationCenter.default.post(name: .reloadData, object: nil)
            return
        }

        let alert = UIAlertController(title: String.localizedStringWithFormat("import_alert_title".localized, files.count), message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "library_title".localized, style: .default) { _ in
          do {
            try DataManager.moveItems(processedItems, into: self.library)
            self.reloadData()
            self.showLoadView(false)
          } catch {
            self.showAlert("error_title".localized, message: error.localizedDescription)
          }
        })

        alert.addAction(UIAlertAction(title: "current_playlist_title".localized, style: .default) { _ in
            self.showLoadView(false)
            NotificationCenter.default.post(name: .reloadData, object: nil)
        })

        alert.addAction(UIAlertAction(title: "new_playlist_button".localized, style: .default) { _ in
            self.presentCreateFolderAlert("new_playlist_button".localized, handler: { title in
              do {
                let folder = try DataManager.createFolder(with: title, in: self.folder, library: self.library)
                try self.move(processedItems, to: folder)
              } catch {
                self.showAlert("error_title".localized, message: error.localizedDescription)
              }

              self.reloadData()
              self.showLoadView(false)
            })
        })

        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Callback events

    @objc override func onBookPlay() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let relativePath = currentBook.relativePath,
            let index = self.folder.itemIndex(with: relativePath),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .playing
    }

    @objc override func onBookPause() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let relativePath = currentBook.relativePath,
            let index = self.folder.itemIndex(with: relativePath),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .paused
    }

    @objc override func onBookStop(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let book = userInfo["book"] as? Book,
            !book.isFault,
            let relativePath = book.relativePath,
            let index = self.folder.itemIndex(with: relativePath),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .stopped
    }

  override func updateProgress(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let currentBook = userInfo["book"] as? Book,
          let index = self.folder.index(for: currentBook),
          let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView else {
      return
    }

    let item = self.items[index]

    let progress = item is Folder
      ? item.progressPercentage
      : userInfo["progress"] as? Double ?? item.progressPercentage

    cell.progress = item.isFinished ? 1.0 : progress
  }

    // MARK: - IBActions

    @IBAction func addAction() {
        self.presentAddOptionsAlert()
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
                _ = try DataManager.createFolder(with: title, in: self.folder, library: self.library)
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

        alert.addAction(UIAlertAction(title: "library_title".localized, style: .default) { [weak self] _ in
          guard let self = self else { return }

          do {
            try DataManager.moveItems(selectedItems, into: self.library)
          } catch {
            self.showAlert("error_title".localized, message: error.localizedDescription)
          }

          self.reloadData()
        })

        alert.addAction(UIAlertAction(title: "new_playlist_button".localized, style: .default) { [weak self] _ in
            guard let self = self else { return }

            self.presentCreateFolderAlert(handler: { title in
              do {
                let folder = try DataManager.createFolder(with: title, in: self.folder, library: self.library)
                try self.move(selectedItems, to: folder)
              } catch {
                self.showAlert("error_title".localized, message: error.localizedDescription)
              }

              self.reloadData()
            })
        })

        let availableFolders = self.items.compactMap { (item) -> Folder? in
            item as? Folder
        }

        let existingFolderAction = UIAlertAction(title: "existing_playlist_button".localized, style: .default) { _ in

            let vc = ItemSelectionViewController()
            vc.items = availableFolders

            vc.onItemSelected = { selectedItem in
              guard let selectedPlaylist = selectedItem as? Folder else { return }

              do {
                try self.move(selectedItems, to: selectedPlaylist)
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

    // MARK: - Methods

    override func sort(by sortType: PlayListSortOrder) {
        self.folder.sort(by: sortType)
    }
}

// MARK: - TableView DataSource

extension PlaylistViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        guard let bookCell = cell as? BookCellView else {
            return cell
        }

        guard
            let currentBook = PlayerManager.shared.currentBook,
            let index = self.folder.index(for: currentBook),
            index == indexPath.row
        else {
            return bookCell
        }

        bookCell.playbackState = .playing

        return bookCell
    }

  override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    guard sourceIndexPath.sectionValue == .data,
          destinationIndexPath.sectionValue == .data,
          sourceIndexPath.row != destinationIndexPath.row  else {
      return
    }

    let item = self.items[sourceIndexPath.row]

    self.folder.removeFromItems(at: sourceIndexPath.row)
    self.folder.insertIntoItems(item, at: destinationIndexPath.row)

    DataManager.saveContext()
    MPPlayableContentManager.shared().reloadData()
  }
}

// MARK: - TableView Delegate

extension PlaylistViewController {
  func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard indexPath.sectionValue == .data else { return nil }

    let item = items[indexPath.row]

    let optionsAction = UIContextualAction(style: .normal, title: "\("options_button".localized)…") { _, _, completion in
      guard let sheet = self.createOptionsSheetController([item]) else { return }

      let deleteAction = UIAlertAction(title: "delete_button".localized, style: .destructive, handler: { _ in
        self.handleDelete(items: [item])
      })

      sheet.addAction(deleteAction)

      self.present(sheet, animated: true, completion: nil)
      completion(true)
    }

    return UISwipeActionsConfiguration(actions: [optionsAction])
  }
}
