//
//  BaseListViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import MediaPlayer
import SwiftReorder
import UIKit

// swiftlint:disable file_length

class BaseListViewController: UIViewController {
    @IBOutlet var emptyStatePlaceholder: UIView!
    @IBOutlet var loadingContainerView: UIView!
    @IBOutlet var loadingTitleLabel: UILabel!
    @IBOutlet var loadingSubtitleLabel: UILabel!
    @IBOutlet var loadingHeightConstraintView: NSLayoutConstraint!
    @IBOutlet var tableView: UITableView!

    @IBAction func didTapSort(_: Any) {
        present(sortDialog(), animated: true, completion: nil)
    }

    var library: Library!

    // TableView's datasource
    var items: [LibraryItem] {
        guard library != nil else {
            return []
        }

        return library.items?.array as? [LibraryItem] ?? []
    }

    // keep in memory current Documents folder
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UINib(nibName: "BookCellView", bundle: nil), forCellReuseIdentifier: "BookCellView")
        tableView.register(UINib(nibName: "AddCellView", bundle: nil), forCellReuseIdentifier: "AddCellView")

        tableView.reorder.delegate = self
        tableView.reorder.cellScale = 1.07
        tableView.reorder.shadowColor = UIColor.black
        tableView.reorder.shadowOffset = CGSize(width: 0.0, height: 3.0)
        tableView.reorder.shadowOpacity = 0.25
        tableView.reorder.shadowRadius = 8.0
        tableView.reorder.animationDuration = 0.15

        // The bottom offset has to be adjusted for the miniplayer as the notification doing this would be sent before the current VC was created
        adjustBottomOffsetForMiniPlayer()

        // Remove the line after the last cell
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))

        // Fixed tableview having strange offset
        edgesForExtendedLayout = UIRectEdge()

        // Prepare empty states
        toggleEmptyStateView()
        showLoadView(false)

        NotificationCenter.default.addObserver(self, selector: #selector(bookReady), name: .bookReady, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateProgress(_:)), name: .updatePercentage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(adjustBottomOffsetForMiniPlayer), name: .playerPresented, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(adjustBottomOffsetForMiniPlayer), name: .playerDismissed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onBookPlay), name: .bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onBookPause), name: .bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onBookStop(_:)), name: .bookStopped, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(onProcessingFile(_:)), name: .processingFile, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onNewFileUrl), name: .newFileUrl, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onNewOperation(_:)), name: .importOperation, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .processingFile, object: nil)
        NotificationCenter.default.removeObserver(self, name: .newFileUrl, object: nil)
        NotificationCenter.default.removeObserver(self, name: .importOperation, object: nil)
    }

    func showLoadView(_ flag: Bool) {
        loadingHeightConstraintView.constant = flag
            ? 65
            : 0
        UIView.animate(withDuration: 0.5) {
            self.loadingContainerView.isHidden = !flag
            self.view.layoutIfNeeded()
        }
    }

    func toggleEmptyStateView() {
        emptyStatePlaceholder.isHidden = !items.isEmpty
    }

    func presentImportFilesAlert() {
        let providerList = UIDocumentPickerViewController(documentTypes: ["public.audio"], in: .import)

        providerList.delegate = self

        if #available(iOS 11.0, *) {
            providerList.allowsMultipleSelection = true
        }

        present(providerList, animated: true, completion: nil)
    }

    func showPlayerView(book: Book) {
        let storyboard = UIStoryboard(name: "Player", bundle: nil)

        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            playerVC.currentBook = book

            present(playerVC, animated: true)
        }
    }

    func setupPlayer(book: Book) {
        // Make sure player is for a different book
        guard
            let currentBook = PlayerManager.shared.currentBook,
            currentBook == book
        else {
            // Handle loading new player
            loadPlayer(book: book)

            return
        }

        showPlayerView(book: currentBook)
    }

    func loadPlayer(book: Book) {
        guard DataManager.exists(book) else {
            showAlert("File missing!", message: "This book’s file was removed from your device. Import the file again to play the book")

            return
        }

        // Replace player with new one
        PlayerManager.shared.load(book) { loaded in
            guard loaded else {
                self.showAlert("File error!", message: "This book's file couldn't be loaded. Make sure you're not using files with DRM protection (like .aax files)")
                return
            }

            self.showPlayerView(book: book)

            PlayerManager.shared.playPause()
        }
    }

    func handleOperationCompletion(_: [FileItem]) {
        fatalError("handleOperationCompletion must be overriden")
    }

    func deleteRows(at indexPaths: [IndexPath]) {
        tableView.beginUpdates()
        tableView.deleteRows(at: indexPaths, with: .none)
        tableView.endUpdates()
        toggleEmptyStateView()
    }

    // MARK: - Callback events

    @objc func reloadData() {
        tableView.beginUpdates()
        tableView.reloadSections(IndexSet(integer: Section.library.rawValue), with: .none)
        tableView.endUpdates()
        toggleEmptyStateView()
    }

    @objc func onNewFileUrl() {
        guard loadingContainerView.isHidden else { return }

        loadingTitleLabel.text = "Preparing to import files"
        loadingSubtitleLabel.isHidden = true
        showLoadView(true)
    }

    // This is called from a background thread inside an ImportOperation
    @objc func onProcessingFile(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let filename = userInfo["filename"] as? String else {
            return
        }

        DispatchQueue.main.async {
            self.loadingSubtitleLabel.text = filename
            self.loadingSubtitleLabel.isHidden = false
        }
    }

    @objc func onNewOperation(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let operation = userInfo["operation"] as? ImportOperation
        else {
            return
        }

        loadingTitleLabel.text = "Processing \(operation.files.count) file(s)"

        operation.completionBlock = {
            DispatchQueue.main.async {
                self.handleOperationCompletion(operation.files)
            }
        }

        DataManager.start(operation)
    }

    @objc func bookReady() {
        tableView.reloadData()
    }

    @objc func onBookPlay() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let index = self.library.itemIndex(with: currentBook.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .library)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .playing
    }

    @objc func onBookPause() {
        guard
            let book = PlayerManager.shared.currentBook,
            let index = self.library.itemIndex(with: book.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .library)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .paused
    }

    @objc func onBookStop(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let book = userInfo["book"] as? Book,
            !book.isFault,
            let index = self.library.itemIndex(with: book.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .library)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .stopped
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
        }), let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: .library)) as? BookCellView else {
            return
        }

        cell.progress = progress
    }

    @objc func adjustBottomOffsetForMiniPlayer() {
        if let rootViewController = self.parent?.parent as? RootViewController {
            tableView.contentInset.bottom = rootViewController.miniPlayerIsHidden ? 0.0 : 88.0
        }
    }

    // MARK: - Sorting

    private func sortDialog() -> UIAlertController {
        let alert = UIAlertController(title: "Sort Files by", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Title", style: .default, handler: { _ in
            do {
                try self.sort(by: .metadataTitle)
                self.tableView.reloadData()
            } catch {
                self.displaySortFailureAlert()
            }
        }))

        alert.addAction(UIAlertAction(title: "Original File Name", style: .default, handler: { _ in
            do {
                try self.sort(by: .fileName)
                self.tableView.reloadData()
            } catch {
                self.displaySortFailureAlert()
            }
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        return alert
    }

    func sort(by _: PlayListSortOrder) throws {
        fatalError()
    }

    private func displaySortFailureAlert() {
        let alert = UIAlertController(
            title: "Error",
            message: "Sorting is unsupported. Please re-import files",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }
}

// MARK: - TableView DataSource

extension BaseListViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == Section.library.rawValue
            ? items.count
            : 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let spacer = tableView.reorder.spacerCell(for: indexPath) {
            return spacer
        }

        guard indexPath.sectionValue != .add,
            let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as? BookCellView else {
            return tableView.dequeueReusableCell(withIdentifier: "AddCellView", for: indexPath)
        }

        let item = items[indexPath.row]

        cell.artwork = item.artwork
        cell.title = item.title
        cell.playbackState = .stopped
        cell.type = item is Playlist ? .playlist : .book

        cell.onArtworkTap = { [weak self] in
            guard let book = item.getBookToPlay() else { return }

            self?.setupPlayer(book: book)
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

    func numberOfSections(in _: UITableView) -> Int {
        return Section.total.rawValue
    }
}

// MARK: - TableView Delegate

extension BaseListViewController: UITableViewDelegate {
    func tableView(_: UITableView, canFocusRowAt _: IndexPath) -> Bool {
        return true
    }

    func tableView(_: UITableView, commit _: UITableViewCellEditingStyle, forRowAt _: IndexPath) {}

    func tableView(_: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        guard indexPath.sectionValue == .library else {
            return .insert
        }
        return .delete
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
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

// MARK: - Reorder Delegate

extension BaseListViewController: TableViewReorderDelegate {
    @objc func tableView(_: UITableView, reorderRowAt _: IndexPath, to _: IndexPath) {}

    func tableView(_: UITableView, canReorderRowAt indexPath: IndexPath) -> Bool {
        return indexPath.sectionValue == .library
    }

    func tableView(_: UITableView, targetIndexPathForReorderFromRowAt sourceIndexPath: IndexPath, to proposedDestinationIndexPath: IndexPath, snapshot: UIView?) -> IndexPath {
        guard proposedDestinationIndexPath.sectionValue == .library else {
            return sourceIndexPath
        }

        if let snapshot = snapshot {
            UIView.animate(withDuration: 0.2) {
                snapshot.transform = CGAffineTransform.identity
            }
        }

        return proposedDestinationIndexPath
    }

    func tableView(_: UITableView, sourceIndexPath _: IndexPath, overIndexPath: IndexPath, snapshot: UIView) {
        guard overIndexPath.sectionValue == .library else {
            return
        }

        let scale: CGFloat = 0.90

        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: {
            snapshot.transform = CGAffineTransform(scaleX: scale, y: scale)
        })
    }

    @objc func tableViewDidFinishReordering(_: UITableView, from _: IndexPath, to _: IndexPath, dropped _: IndexPath?) {
        //
    }
}

// MARK: DocumentPicker Delegate

extension BaseListViewController: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            DataManager.processFile(at: url)
        }
    }
}
