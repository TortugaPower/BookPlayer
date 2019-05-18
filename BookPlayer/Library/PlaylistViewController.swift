//
//  PlaylistViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlaylistViewController: ItemListViewController {
    var playlist: Playlist!

    override var items: [LibraryItem] {
        return self.playlist.books?.array as? [LibraryItem] ?? []
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.toggleEmptyStateView()

        self.navigationItem.title = self.playlist.title
    }

    override func reloadData() {
        super.reloadData()
        NotificationCenter.default.post(name: .reloadData, object: nil)
    }

    override func handleOperationCompletion(_ files: [FileItem]) {
        DataManager.insertBooks(from: files, into: self.playlist) {
            self.reloadData()
        }

        guard files.count > 1 else {
            self.showLoadView(false)
            NotificationCenter.default.post(name: .reloadData, object: nil)
            return
        }

        let alert = UIAlertController(title: "Import \(files.count) files into", message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Library", style: .default) { _ in
            DataManager.insertBooks(from: files, into: self.library) {
                self.reloadData()
                self.showLoadView(false)
            }
        })

        alert.addAction(UIAlertAction(title: "Current Playlist", style: .default) { _ in
            self.showLoadView(false)
            NotificationCenter.default.post(name: .reloadData, object: nil)
        })

        alert.addAction(UIAlertAction(title: "New Playlist", style: .default) { _ in
            var placeholder = "New Playlist"

            if let file = files.first {
                placeholder = file.originalUrl.deletingPathExtension().lastPathComponent
            }

            self.presentCreatePlaylistAlert(placeholder, handler: { title in
                let playlist = DataManager.createPlaylist(title: title, books: [])

                DataManager.insert(playlist, into: self.library)

                DataManager.insertBooks(from: files, into: playlist) {
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
            let fileURL = currentBook.fileURL,
            let index = self.playlist.itemIndex(with: fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .playing
    }

    @objc override func onBookPause() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let fileURL = currentBook.fileURL,
            let index = self.playlist.itemIndex(with: fileURL),
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
            let fileURL = book.fileURL,
            let index = self.playlist.itemIndex(with: fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .stopped
    }

    // MARK: - IBActions

    @IBAction func addAction() {
        self.presentImportFilesAlert()
    }

    override func handleMove(_ selectedItems: [LibraryItem]) {
        guard let books = selectedItems as? [Book] else { return }

        let alert = UIAlertController(title: "Choose destination", message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Library", style: .default) { _ in
            let bookSet = NSOrderedSet(array: books)
            self.playlist.removeFromBooks(bookSet)
            self.library.addToItems(bookSet)
            DataManager.saveContext()

            self.reloadData()
        })

        alert.addAction(UIAlertAction(title: "New Playlist", style: .default) { _ in
            self.presentCreatePlaylistAlert(handler: { title in
                self.playlist.removeFromBooks(NSOrderedSet(array: books))
                let playlist = DataManager.createPlaylist(title: title, books: books)

                DataManager.insert(playlist, into: self.library)

                self.reloadData()
            })
        })

        let availablePlaylists = self.library.itemsArray.compactMap({ (item) -> Playlist? in
            item as? Playlist
        })

        let existingPlaylistAction = UIAlertAction(title: "Existing Playlist", style: .default) { _ in

            let vc = ItemSelectionViewController()
            vc.items = availablePlaylists

            vc.onItemSelected = { selectedItem in
                guard let selectedPlaylist = selectedItem as? Playlist else { return }
                self.move(selectedItems, to: selectedPlaylist)
            }

            let nav = AppNavigationController(rootViewController: vc)
            self.present(nav, animated: true, completion: nil)
        }

        existingPlaylistAction.isEnabled = !availablePlaylists.isEmpty
        alert.addAction(existingPlaylistAction)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        self.present(alert, animated: true, completion: nil)
    }

    override func handleTrash(_ selectedItems: [LibraryItem]) {
        guard let books = selectedItems as? [Book] else { return }

        self.handleDelete(books: books)
    }

    // MARK: - Methods

    override func sort(by sortType: PlayListSortOrder) {
        self.playlist.sort(by: sortType)
    }

    override func handleDelete(books: [Book]) {
        let alert = UIAlertController(title: "Do you want to delete \(books.count) items?", message: nil, preferredStyle: .alert)

        if books.count == 1, let book = books.first {
            alert.title = "Do you want to delete “\(book.title!)”?"
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
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
            let fileURL = currentBook.fileURL,
            let index = self.playlist.itemIndex(with: fileURL),
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
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)

        guard !tableView.isEditing else {
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.sectionValue == .data else {
            if indexPath.sectionValue == .add {
                self.presentImportFilesAlert()
            }

            return
        }

        guard let book = self.items[indexPath.row] as? Book else { return }

        self.setupPlayer(book: book)
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.sectionValue == .data, let book = self.items[indexPath.row] as? Book else {
            return nil
        }

        let optionsAction = UITableViewRowAction(style: .normal, title: "Options…") { _, _ in
            let sheet = self.createOptionsSheetController(book)

            let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
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

        // swiftlint:disable force_cast
        let book = items[sourceIndexPath.row] as! Book

        playlist.removeFromBooks(at: sourceIndexPath.row)
        playlist.insertIntoBooks(book, at: destinationIndexPath.row)

        DataManager.saveContext()
    }

    override func tableView(_ tableView: UITableView, sourceIndexPath: IndexPath, overIndexPath: IndexPath, snapshot: UIView) {}
}
