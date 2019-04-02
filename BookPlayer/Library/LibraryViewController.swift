//
//  LibraryViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/7/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import MediaPlayer
import SwiftReorder
import UIKit

// swiftlint:disable file_length

class LibraryViewController: ItemListViewController, UIGestureRecognizerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        // VoiceOver
        self.setupCustomRotors()

        // enables pop gesture on pushed controller
        self.navigationController!.interactivePopGestureRecognizer!.delegate = self

        // handle CoreData migration into shared app groups
        if !UserDefaults.standard.bool(forKey: Constants.UserDefaults.appGroupsMigration.rawValue) {
            self.migrateCoreDataStack()
            UserDefaults.standard.set(true, forKey: Constants.UserDefaults.appGroupsMigration.rawValue)
        }

        self.loadLibrary()

        self.loadLastBook()
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
    }

    func loadLibrary() {
        self.library = DataManager.getLibrary()

        self.toggleEmptyStateView()

        self.tableView.reloadData()

        DataManager.notifyPendingFiles()
    }

    func loadLastBook() {
        guard let identifier = UserDefaults.standard.string(forKey: Constants.UserDefaults.lastPlayedBook.rawValue),
            let item = self.library.getItem(with: identifier) else {
            return
        }

        var book: Book?

        if
            let playlist = item as? Playlist,
            let index = playlist.itemIndex(with: identifier),
            let playlistBook = playlist.getBook(at: index) {
            book = playlistBook
        } else if let lastPlayedBook = item as? Book {
            book = lastPlayedBook
        }

        guard book != nil else { return }

        // Preload player
        PlayerManager.shared.load(book!) { loaded in
            guard loaded else { return }

            NotificationCenter.default.post(name: .playerDismissed, object: nil, userInfo: nil)
            if UserDefaults.standard.bool(forKey: Constants.UserActivityPlayback) {
                UserDefaults.standard.removeObject(forKey: Constants.UserActivityPlayback)
                PlayerManager.shared.play()
            }
        }
    }

    /**
     *  Migrates existing stack into the new container app groups.
     *  In case it fails, it loads all the files from the Processed folder
     */
    func migrateCoreDataStack() {
        DataManager.makeFilesPublic()
        do {
            try DataManager.migrateStack()
        } catch {
            // Migration failed, fallback: load all books from processed folder
            if let fileUrls = DataManager.getFiles(from: DataManager.getProcessedFolderURL()) {
                let fileItems = fileUrls.map { (url) -> FileItem in
                    return FileItem(originalUrl: url, processedUrl: url, destinationFolder: url)
                }
                DataManager.insertBooks(from: fileItems, into: self.library) {
                    self.reloadData()
                }
            }
        }
    }

    override func handleOperationCompletion(_ files: [FileItem]) {
        DataManager.insertBooks(from: files, into: self.library) {
            self.reloadData()
        }

        guard files.count > 1 else {
            self.showLoadView(false)
            return
        }

        let alert = UIAlertController(title: "Import \(files.count) files into", message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Library", style: .default) { _ in
            self.showLoadView(false)
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

    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        return navigationController!.viewControllers.count > 1
    }

    private func presentPlaylist(_ playlist: Playlist) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        guard let playlistVC = storyboard.instantiateViewController(withIdentifier: "PlaylistViewController") as? PlaylistViewController else {
            return
        }

        playlistVC.library = library
        playlistVC.playlist = playlist

        navigationController?.pushViewController(playlistVC, animated: true)
    }

    func handleDelete(items: [LibraryItem]) {
        let alert = UIAlertController(title: "Do you want to delete \(items.count) items?",
                                      message: "This will remove all files inside selected playlists as well.",
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        var deleteActionTitle = "Delete"

        if items.count == 1, let playlist = items.first as? Playlist {
            deleteActionTitle = "Delete playlist and files"

            alert.title = "Do you want to delete “\(playlist.title!)”?"
            alert.message = "Deleting only the playlist will move all its files back to the Library."
            alert.addAction(UIAlertAction(title: "Delete playlist only", style: .default, handler: { _ in
                self.delete(items, mode: .shallow)
            }))
        }

        alert.addAction(UIAlertAction(title: deleteActionTitle, style: .destructive, handler: { _ in
            self.delete(items, mode: .deep)
        }))

        present(alert, animated: true, completion: nil)
    }

    // MARK: - Callback events

    @objc func onNewFileUrl() {
        guard self.loadingView.isHidden else { return }
        let loadingTitle = "Preparing to import files"
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

        let loadingTitle = "Processing \(operation.files.count) file(s)"

        self.showLoadView(true, title: loadingTitle)

        if let vc = self.navigationController?.visibleViewController as? PlaylistViewController {
            vc.showLoadView(true, title: loadingTitle)
        }

        operation.completionBlock = {
            DispatchQueue.main.async {
                guard let vc = self.navigationController?.visibleViewController as? PlaylistViewController else {
                    self.handleOperationCompletion(operation.files)
                    return
                }
                self.showLoadView(false)
                vc.handleOperationCompletion(operation.files)
            }
        }

        DataManager.start(operation)
    }

    // MARK: - IBActions

    @IBAction func addAction() {
        let alertController = UIAlertController(title: nil,
                                                message: "You can also add files via AirDrop. Send an audiobook file to your device and select BookPlayer from the list that appears.",
                                                preferredStyle: .actionSheet)

        alertController.addAction(UIAlertAction(title: "Import files", style: .default) { _ in
            self.presentImportFilesAlert()
        })

        alertController.addAction(UIAlertAction(title: "Create playlist", style: .default) { _ in
            self.presentCreatePlaylistAlert(handler: { title in
                let playlist = DataManager.createPlaylist(title: title, books: [])

                DataManager.insert(playlist, into: self.library)

                self.reloadData()
            })
        })

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alertController, animated: true, completion: nil)
    }

    // Sorting
    override func sort(by sortType: PlayListSortOrder) {
        library.sort(by: sortType)
    }

    override func handleMove(_ selectedItems: [LibraryItem]) {
        let alert = UIAlertController(title: "Choose destination", message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "New Playlist", style: .default) { _ in
            self.presentCreatePlaylistAlert(handler: { title in
                let playlist = DataManager.createPlaylist(title: title, books: [])
                DataManager.insert(playlist, into: self.library)
                self.move(selectedItems, to: playlist)
            })
        })

        let availablePlaylists = self.items.compactMap({ (item) -> Playlist? in
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
        guard let books = selectedItems as? [Book] else {
            self.handleDelete(items: selectedItems)
            return
        }

        self.handleDelete(books: books)
    }
}

// MARK: Accessibility

extension LibraryViewController {
    private func setupCustomRotors() {
        accessibilityCustomRotors = [rotorFactory(name: "Books", type: .book), rotorFactory(name: "Playlists", type: .playlist)]
    }

    private func rotorFactory(name: String, type: BookCellType) -> UIAccessibilityCustomRotor {
        return UIAccessibilityCustomRotor(name: name) { (predicate) -> UIAccessibilityCustomRotorItemResult? in
            let forward: Bool = (predicate.searchDirection == .next)

            let playListCells = self.tableView.visibleCells.filter({ (cell) -> Bool in
                guard let cell = cell as? BookCellView else { return false }
                return cell.type == type
            })

            var currentIndex = forward ? -1 : playListCells.count
            //
            if let currentElement = predicate.currentItem.targetElement {
                if let cell = currentElement as? BookCellView {
                    currentIndex = playListCells.firstIndex(of: cell) ?? currentIndex
                }
            }
            let nextIndex = forward ? currentIndex + 1 : currentIndex - 1

            while nextIndex >= 0 && nextIndex < playListCells.count {
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

        let optionsAction = UITableViewRowAction(style: .normal, title: "Options…") { _, _ in
            let sheet = self.createOptionsSheetController(item)

            // "…" on a button indicates a follow up dialog instead of an immmediate action in macOS and iOS
            var title = "Delete…"

            // Remove the dots if trying to delete an empty playlist
            if let playlist = item as? Playlist {
                title = playlist.hasBooks() ? title : "Delete"
            }

            let deleteAction = UIAlertAction(title: title, style: .destructive) { _ in
                guard let book = self.items[indexPath.row] as? Book else {
                    guard let playlist = self.items[indexPath.row] as? Playlist else { return }

                    guard playlist.hasBooks() else {
                        DataManager.delete([playlist])
                        self.deleteRows(at: [indexPath])
                        return
                    }

                    self.handleDelete(items: [playlist])

                    return
                }

                self.handleDelete(books: [book])
            }

            sheet.addAction(deleteAction)

            self.present(sheet, animated: true, completion: nil)
        }

        return [optionsAction]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)

        guard !tableView.isEditing else {
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.sectionValue == .data else {
            if indexPath.sectionValue == .add {
                self.addAction()
            }

            return
        }

        if let playlist = self.items[indexPath.row] as? Playlist {
            self.presentPlaylist(playlist)

            return
        }

        if let book = self.items[indexPath.row] as? Book {
            setupPlayer(book: book)
        }
    }
}

// MARK: - TableView DataSource

extension LibraryViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        guard let bookCell = cell as? BookCellView,
            let currentBook = PlayerManager.shared.currentBook,
            let fileURL = currentBook.fileURL,
            let index = self.library.itemIndex(with: fileURL),
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
        guard let overIndexPath = overIndexPath, overIndexPath.sectionValue == .data else { return }

        let sourceItem = self.items[finalDestinationIndexPath.row]
        let destinationItem = self.items[overIndexPath.row]

        guard let playlist = destinationItem as? Playlist ?? sourceItem as? Playlist else {
            let minIndex = min(finalDestinationIndexPath.row, overIndexPath.row)

            self.presentCreatePlaylistAlert(destinationItem.title, handler: { title in
                let playlist = DataManager.createPlaylist(title: title, books: [])
                DataManager.insert(playlist, into: self.library, at: minIndex)
                self.move([sourceItem, destinationItem], to: playlist)

                self.reloadData()
            })
            return
        }

        let selectedItem = playlist == destinationItem
            ? sourceItem
            : destinationItem

        let alert = UIAlertController(title: "Move to playlist",
                                      message: "Do you want to move '\(selectedItem.title!)' to '\(playlist.title!)'?",
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        alert.addAction(UIAlertAction(title: "Move", style: .default, handler: { _ in
            self.move([selectedItem], to: playlist)
            self.reloadData()
        }))

        self.present(alert, animated: true, completion: nil)
    }
}
