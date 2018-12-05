//
//  PlaylistViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlaylistViewController: BaseListViewController {
    var playlist: Playlist!

    override var items: [LibraryItem] {
        return self.playlist.books?.array as? [LibraryItem] ?? []
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.toggleEmptyStateView()

        self.navigationItem.title = self.playlist.title
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
                NotificationCenter.default.post(name: .reloadData, object: nil)
            }
        })

        alert.addAction(UIAlertAction(title: "Current Playlist", style: .default) { _ in
            self.showLoadView(false)
            NotificationCenter.default.post(name: .reloadData, object: nil)
        })

        let vc = self.presentedViewController ?? self

        vc.present(alert, animated: true, completion: nil)
    }

    // MARK: - Callback events

    @objc override func onBookPlay() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let index = self.playlist.itemIndex(with: currentBook.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .library)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .playing
    }

    @objc override func onBookPause() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let index = self.playlist.itemIndex(with: currentBook.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .library)) as? BookCellView
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
            let index = self.playlist.itemIndex(with: book.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .library)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .stopped
    }

    // MARK: - IBActions

    @IBAction func addAction() {
        self.presentImportFilesAlert()
    }

    override func didTapTrash(_ sender: UIButton) {
        super.didTapTrash(sender)

        guard let indexPaths = self.tableView.indexPathsForSelectedRows else {
            return
        }

        let selectedItems = indexPaths.map { (indexPath) -> LibraryItem in
            return self.items[indexPath.row]
        }

        guard !selectedItems.isEmpty,
            let books = selectedItems as? [Book] else { return }

        self.handleDelete(books: books)
    }

    // MARK: - Methods

    override func sort(by sortType: PlayListSortOrder) {
        self.playlist.sort(by: sortType)
    }

    func handleDelete(books: [Book]) {
        let alert = UIAlertController(title: "Do you want to delete \(items.count) items?", message: nil, preferredStyle: .alert)

        if books.count == 1, let book = books.first {
            alert.title = "Do you want to delete “\(book.title!)”?"
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        alert.addAction(UIAlertAction(title: "Move to Library", style: .default, handler: { _ in
//            DataManager.delete(book, from: self.library, mode: .shallow)
            DataManager.delete(books, mode: .shallow)
            self.reloadData()

            NotificationCenter.default.post(name: .reloadData, object: nil)
        }))

        alert.addAction(UIAlertAction(title: "Delete completely", style: .destructive, handler: { _ in
            DataManager.delete(books)

            self.reloadData()

            NotificationCenter.default.post(name: .reloadData, object: nil)
        }))

        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: - DocumentPicker Delegate

extension PlaylistViewController {
    override func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            // context put in playlist
            DataManager.processFile(at: url)
        }
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
            let index = self.playlist.itemIndex(with: currentBook.fileURL),
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

        guard indexPath.sectionValue == .library else {
            if indexPath.sectionValue == .add {
                self.presentImportFilesAlert()
            }

            return
        }

        guard let book = self.items[indexPath.row] as? Book else { return }

        self.setupPlayer(book: book)
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.sectionValue == .library, let book = self.items[indexPath.row] as? Book else {
            return nil
        }

        let exportAction = UITableViewRowAction(style: .normal, title: "Export") { _, _ in
            let bookProvider = BookActivityItemProvider(book)

            let shareController = UIActivityViewController(activityItems: [bookProvider], applicationActivities: nil)

            shareController.excludedActivityTypes = [.copyToPasteboard]

            self.present(shareController, animated: true, completion: nil)
        }

        let optionsAction = UITableViewRowAction(style: .default, title: "Options") { _, _ in
            self.handleDelete(books: [book])
        }

        optionsAction.backgroundColor = .gray

        return [optionsAction, exportAction]
    }
}

// MARK: - Reorder Delegate

extension PlaylistViewController {
    override func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard destinationIndexPath.sectionValue == .library else {
            return
        }

        // swiftlint:disable force_cast
        let book = items[sourceIndexPath.row] as! Book

        playlist.removeFromBooks(at: sourceIndexPath.row)
        playlist.insertIntoBooks(book, at: destinationIndexPath.row)

        DataManager.saveContext()
    }
}
