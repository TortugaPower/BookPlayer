//
//  PlaylistViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
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
        self.sendSignal(.folderScreen, with: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let identifier = currentBook.identifier,
            let index = self.folder.itemIndex(with: identifier) else {
            return
        }

        tableView.scrollToRow(at: IndexPath(row: index, section: .data), at: .middle, animated: true)
    }

    override func reloadData() {
        super.reloadData()
        NotificationCenter.default.post(name: .reloadData, object: nil)
    }

    override func handleOperationCompletion(_ files: [FileItem]) {
        DataManager.insertBooks(from: files, into: self.folder) {
            self.reloadData()
        }

        guard files.count > 1 else {
            self.showLoadView(false)
            NotificationCenter.default.post(name: .reloadData, object: nil)
            return
        }

        let alert = UIAlertController(title: String.localizedStringWithFormat("import_alert_title".localized, files.count), message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "library_title".localized, style: .default) { _ in
            DataManager.insertBooks(from: files, into: self.library) {
                self.reloadData()
                self.showLoadView(false)
            }
        })

        alert.addAction(UIAlertAction(title: "current_playlist_title".localized, style: .default) { _ in
            self.showLoadView(false)
            NotificationCenter.default.post(name: .reloadData, object: nil)
        })

        alert.addAction(UIAlertAction(title: "new_playlist_button".localized, style: .default) { _ in
            var placeholder = "new_playlist_button".localized

            if let file = files.first {
                placeholder = file.originalUrl.deletingPathExtension().lastPathComponent
            }

            self.presentCreateFolderAlert(placeholder, handler: { title in
                let folder = DataManager.createFolder(title: title, items: [])

                DataManager.insert(folder, into: self.library)

                DataManager.insertBooks(from: files, into: folder) {
                    self.reloadData()
                    self.showLoadView(false)
                }

            })
        })

        let vc = self.presentedViewController ?? self

        vc.present(alert, animated: true, completion: nil)
    }

    // MARK: - Callback events

    @objc override func onBookPlay() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let identifier = currentBook.identifier,
            let index = self.folder.itemIndex(with: identifier),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .playing
    }

    @objc override func onBookPause() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let identifier = currentBook.identifier,
            let index = self.folder.itemIndex(with: identifier),
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
            let identifier = book.identifier,
            let index = self.folder.itemIndex(with: identifier),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .stopped
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
                let folder = DataManager.createFolder(title: title, items: [])

                DataManager.insert(folder, into: self.folder)

                self.reloadData()
            })
        })

        alertController.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel))

        present(alertController, animated: true, completion: nil)
    }

    override func handleMove(_ selectedItems: [LibraryItem]) {
        guard let books = selectedItems as? [Book] else { return }

        let alert = UIAlertController(title: "choose_destination_title".localized, message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "library_title".localized, style: .default) { _ in
            let bookSet = NSOrderedSet(array: books)
            self.folder.removeFromItems(bookSet)
            self.library.addToItems(bookSet)
            DataManager.saveContext()

            self.reloadData()
        })

        alert.addAction(UIAlertAction(title: "new_playlist_button".localized, style: .default) { _ in
            self.presentCreateFolderAlert(handler: { title in
                self.folder.removeFromItems(NSOrderedSet(array: books))
                let folder = DataManager.createFolder(title: title, items: books)

                DataManager.insert(folder, into: self.library)

                self.reloadData()
            })
        })

        let availableFolders = self.library.itemsArray.compactMap { (item) -> Folder? in
            item as? Folder
        }

        let existingFolderAction = UIAlertAction(title: "existing_playlist_button".localized, style: .default) { _ in

            let vc = ItemSelectionViewController()
            vc.items = availableFolders

            vc.onItemSelected = { selectedItem in
                guard let selectedPlaylist = selectedItem as? Folder else { return }
                self.move(selectedItems, to: selectedPlaylist)
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
        guard let books = selectedItems as? [Book] else { return }

        self.handleDelete(books: books)
    }

    // MARK: - Methods

    override func sort(by sortType: PlayListSortOrder) {
        self.folder.sort(by: sortType)
    }

    override func handleDelete(books: [Book]) {
        let alert = UIAlertController(title: String.localizedStringWithFormat("delete_multiple_items_title".localized, books.count), message: nil, preferredStyle: .alert)

        if books.count == 1, let book = books.first {
            alert.title = String(format: "delete_single_item_title".localized, book.title!)
        }

        alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

        alert.addAction(UIAlertAction(title: "delete_button".localized, style: .destructive, handler: { _ in
            self.delete(books, mode: .deep)
        }))

        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: - TableView DataSource

extension PlaylistViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        guard let bookCell = cell as? BookCellView else {
            return cell
        }

        bookCell.type = .file

        guard
            let currentBook = PlayerManager.shared.currentBook,
            let identifier = currentBook.identifier,
            let index = self.folder.itemIndex(with: identifier),
            index == indexPath.row
        else {
            return bookCell
        }

        bookCell.playbackState = .playing

        return bookCell
    }
}

// MARK: - TableView Delegate

extension PlaylistViewController {
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.sectionValue == .data, let book = self.items[indexPath.row] as? Book else {
            return nil
        }

        let optionsAction = UITableViewRowAction(style: .normal, title: "\("options_button".localized)…") { _, _ in
            guard let sheet = self.createOptionsSheetController([book]) else { return }

            let deleteAction = UIAlertAction(title: "delete_button".localized, style: .destructive, handler: { _ in
                self.handleDelete(books: [book])
            })

            sheet.addAction(deleteAction)

            self.present(sheet, animated: true, completion: nil)
        }

        return [optionsAction]
    }
}

// MARK: - Reorder Delegate

extension PlaylistViewController {
    override func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        super.tableView(tableView, reorderRowAt: sourceIndexPath, to: destinationIndexPath)

        guard destinationIndexPath.sectionValue == .data else {
            return
        }

        let item = self.items[sourceIndexPath.row]

        self.folder.removeFromItems(at: sourceIndexPath.row)
        self.folder.insertIntoItems(item, at: destinationIndexPath.row)

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
                let folder = DataManager.createFolder(title: title, items: [])
                DataManager.insert(folder, into: self.folder, at: minIndex)
                self.move([sourceItem, destinationItem], to: folder)

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
            self.move([selectedItem], to: folder)
            self.reloadData()
        }))

        self.present(alert, animated: true, completion: nil)
    }
}
