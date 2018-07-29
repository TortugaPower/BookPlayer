//
//  BaseListViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import MediaPlayer
import MBProgressHUD
import SwiftReorder

// swiftlint:disable file_length

class BaseListViewController: UIViewController {
    @IBOutlet weak var emptyStatePlaceholder: UIView!

    var library: Library!

    // TableView's datasource
    var items: [LibraryItem] {
        guard self.library != nil else {
            return []
        }

        return self.library.items?.array as? [LibraryItem] ?? []
    }

    var processingUrls = [URL]()

    let queue = OperationQueue()
    var token: NSKeyValueObservation?

    @IBOutlet weak var tableView: UITableView!

    // keep in memory current Documents folder
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.queue.maxConcurrentOperationCount = 1

        self.token = self.queue.observe(\.operationCount) { (opQueue, _) in
            guard opQueue.operationCount == 0 else {
                return
            }

            DispatchQueue.main.async {
                MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            }
        }

        self.tableView.register(UINib(nibName: "BookCellView", bundle: nil), forCellReuseIdentifier: "BookCellView")
        self.tableView.register(UINib(nibName: "AddCellView", bundle: nil), forCellReuseIdentifier: "AddCellView")

        self.tableView.reorder.delegate = self
        self.tableView.reorder.cellScale = 1.07
        self.tableView.reorder.shadowColor = UIColor.black
        self.tableView.reorder.shadowOffset = CGSize(width: 0.0, height: 3.0)
        self.tableView.reorder.shadowOpacity = 0.25
        self.tableView.reorder.shadowRadius = 8.0
        self.tableView.reorder.animationDuration = 0.15

        // The bottom offset has to be adjusted for the miniplayer as the notification doing this would be sent before the current VC was created
        self.adjustBottomOffsetForMiniPlayer()

        // Remove the line after the last cell
        self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))

        // Fixed tableview having strange offset
        self.edgesForExtendedLayout = UIRectEdge()

        // Prepare empty states
        self.view.addSubview(self.emptyStatePlaceholder)
        self.toggleEmptyStateView()

        NotificationCenter.default.addObserver(self, selector: #selector(self.bookReady), name: Notification.Name.AudiobookPlayer.bookReady, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateProgress(_:)), name: Notification.Name.AudiobookPlayer.updatePercentage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.adjustBottomOffsetForMiniPlayer), name: Notification.Name.AudiobookPlayer.playerPresented, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.adjustBottomOffsetForMiniPlayer), name: Notification.Name.AudiobookPlayer.playerDismissed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookStop(_:)), name: Notification.Name.AudiobookPlayer.bookStopped, object: nil)
    }

    @objc func onBookPlay() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let index = self.library.itemIndex(with: currentBook.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .playing
    }

    @objc func onBookPause() {
        guard
            let book = PlayerManager.shared.currentBook,
            let index = self.library.itemIndex(with: book.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .paused
    }

    @objc func onBookStop(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let book = userInfo["book"] as? Book,
            let index = self.library.itemIndex(with: book.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .stopped
    }

    @objc func adjustBottomOffsetForMiniPlayer() {
        if let rootViewController = self.parent?.parent as? RootViewController {
            self.tableView.contentInset.bottom = rootViewController.miniPlayerIsHidden ? 0.0 : 88.0
        }
    }

    func toggleEmptyStateView() {
        self.emptyStatePlaceholder.isHidden = !self.items.isEmpty
    }

    func presentImportFilesAlert() {
        let providerList = UIDocumentPickerViewController(documentTypes: ["public.audio"], in: .import)

        providerList.delegate = self

        if #available(iOS 11.0, *) {
            providerList.allowsMultipleSelection = true
        }

        self.present(providerList, animated: true, completion: nil)
    }

    func showPlayerView(book: Book) {
        let storyboard = UIStoryboard(name: "Player", bundle: nil)

        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            playerVC.currentBook = book

            self.present(playerVC, animated: true)
        }
    }

    func queueBooksForPlayback(_ startItem: LibraryItem, forceAutoplay: Bool = false) -> [Book] {
        var books = [Book]()
        let shouldAutoplayLibrary = UserDefaults.standard.bool(forKey: UserDefaultsConstants.autoplayEnabled)
        let shouldAutoplay = shouldAutoplayLibrary || forceAutoplay

        if let book = startItem as? Book {
            books.append(book)
        }

        if let playlist = startItem as? Playlist {
            books.append(contentsOf: playlist.getRemainingBooks())
        }

        guard
            shouldAutoplay,
            let remainingItems = self.items.split(whereSeparator: { $0 == startItem }).last
            else {
                return books
        }

        for item in remainingItems {
            if let playlist = item as? Playlist {
                books.append(contentsOf: playlist.getRemainingBooks())
            } else if let book = item as? Book, !book.isCompleted {
                books.append(book)
            }
        }

        return books
    }

    func setupPlayer(books: [Book] = []) {
        // Stop setup if no books were found
        if books.isEmpty {
            return
        }

        // Make sure player is for a different book
        guard
            let firstBook = books.first,
            let currentBook = PlayerManager.shared.currentBook,
            currentBook == firstBook
        else {
            // Handle loading new player
            self.loadPlayer(books: books)

            return
        }

        self.showPlayerView(book: currentBook)
    }

    func loadPlayer(books: [Book]) {
        guard let book = books.first else { return }

        guard DataManager.exists(book) else {
            self.showAlert("File missing!", message: "This book’s file was removed from your device. Import the file again to play the book")

            return
        }

        MBProgressHUD.showAdded(to: self.view, animated: true)

        // Replace player with new one
        PlayerManager.shared.load(books) { (loaded) in
            guard loaded else {
                MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
                self.showAlert("File error!", message: "This book's file couldn't be loaded. Make sure you're not using files with DRM protection (like .aax files)")
                return
            }
            self.showPlayerView(book: book)

            PlayerManager.shared.playPause()
        }
    }

    @objc func bookReady() {
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
        self.tableView.reloadData()
    }

    func loadFile(urls: [BookURL]) {
        fatalError("loadFiles must be overriden")
    }

    @objc func updateProgress(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            let progress = userInfo["progress"] as? Double else {
                return
        }

        guard let index = (self.items.index { (item) -> Bool in
            if let book = item as? Book {
                return book.fileURL == fileURL
            }

            return false
        }), let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? BookCellView else {
            return
        }

        cell.progress = progress
    }

    @objc func openURL(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            !self.processingUrls.contains(fileURL) else {
                return
        }

        self.processingUrls.append(fileURL)
        MBProgressHUD.showAdded(to: self.view, animated: true)

        let destinationFolder = DataManager.getProcessedFolderURL()

        DataManager.processFile(at: fileURL, destinationFolder: destinationFolder) { (processedURL) in
            guard let processedURL = processedURL else {
                MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
                return
            }

            let bookUrl = BookURL(original: fileURL, processed: processedURL)
            self.loadFile(urls: [bookUrl])

            if let index = self.processingUrls.index(where: { $0 == fileURL }) {
                self.processingUrls.remove(at: index)
            }
        }
    }
}

extension BaseListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == 0 else {
            return 1
        }

        return self.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let spacer = tableView.reorder.spacerCell(for: indexPath) {
            return spacer
        }

        guard
            indexPath.section == 0,
            let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as? BookCellView
        else {
            return tableView.dequeueReusableCell(withIdentifier: "AddCellView", for: indexPath)
        }

        let item = self.items[indexPath.row]

        cell.artwork = item.artwork
        cell.title = item.title
        cell.playbackState = .stopped
        cell.type = item is Playlist ? .playlist : .book

        cell.onArtworkTap = { [weak self] in
            guard let books = self?.queueBooksForPlayback(item) else {
                return
            }

            self?.setupPlayer(books: books)
        }

        if let book = item as? Book {
            cell.subtitle = book.author
            cell.progress = book.progress
        } else if let playlist = item as? Playlist {
            cell.subtitle = playlist.info()
            cell.progress = playlist.totalProgress()
        }

        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
}

extension BaseListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        guard indexPath.section == 0 else {
            return .insert
        }
        return .delete
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let index = tableView.indexPathForSelectedRow else {
            return indexPath
        }

        tableView.deselectRow(at: index, animated: true)

        return indexPath
    }
}

extension BaseListViewController: TableViewReorderDelegate {
    @objc func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {}

    func tableView(_ tableView: UITableView, canReorderRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0
    }

    func tableView(_ tableView: UITableView, targetIndexPathForReorderFromRowAt sourceIndexPath: IndexPath, to proposedDestinationIndexPath: IndexPath, snapshot: UIView?) -> IndexPath {
        guard proposedDestinationIndexPath.section == 0 else {
            return sourceIndexPath
        }

        if let snapshot = snapshot {
            UIView.animate(withDuration: 0.2) {
                snapshot.transform = CGAffineTransform.identity
            }
        }

        return proposedDestinationIndexPath
    }

    func tableView(_ tableView: UITableView, sourceIndexPath: IndexPath, overIndexPath: IndexPath, snapshot: UIView) {
        guard overIndexPath.section == 0 else {
            return
        }

        let scale: CGFloat = 0.90

        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: {
            snapshot.transform = CGAffineTransform(scaleX: scale, y: scale)
        })
    }

    @objc func tableViewDidFinishReordering(_ tableView: UITableView, from initialSourceIndexPath: IndexPath, to finalDestinationIndexPath: IndexPath, dropped overIndexPath: IndexPath?) {}
}

extension BaseListViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            let userInfo = ["fileURL": url]
            NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.libraryOpenURL, object: nil, userInfo: userInfo)
        }
    }
}
