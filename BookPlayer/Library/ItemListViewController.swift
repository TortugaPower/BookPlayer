//
//  ItemListViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import MediaPlayer
import SwiftReorder
import Themeable
import UIKit

// swiftlint:disable file_length

class ItemListViewController: UIViewController, ItemList, ItemListAlerts, ItemListActions {
    @IBOutlet weak var emptyStatePlaceholder: UIView!
    @IBOutlet weak var loadingView: LoadingView!
    @IBOutlet weak var loadingHeightConstraintView: NSLayoutConstraint!
    @IBOutlet weak var bulkControls: BulkControlsView!

    @IBOutlet weak var tableView: UITableView!

    var library: Library!

    // TableView's datasource
    var items: [LibraryItem] {
        guard self.library != nil else {
            return []
        }

        return self.library.items?.array as? [LibraryItem] ?? []
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupBulkControls()

        self.navigationItem.rightBarButtonItem = self.editButtonItem

        setUpTheming()

        self.tableView.register(UINib(nibName: "BookCellView", bundle: nil), forCellReuseIdentifier: "BookCellView")
        self.tableView.register(UINib(nibName: "AddCellView", bundle: nil), forCellReuseIdentifier: "AddCellView")
        self.tableView.allowsSelection = true
        self.tableView.allowsMultipleSelectionDuringEditing = true

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
        self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: 1))

        // Fixed tableview having strange offset
        self.edgesForExtendedLayout = UIRectEdge()

        // Prepare empty states
        self.toggleEmptyStateView()
        self.showLoadView(false)

        self.setupObservers()
    }

    func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookReady), name: .bookReady, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateProgress(_:)), name: .updatePercentage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateProgress(_:)), name: .bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.adjustBottomOffsetForMiniPlayer), name: .playerPresented, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.adjustBottomOffsetForMiniPlayer), name: .playerDismissed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: .bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: .bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookStop(_:)), name: .bookStopped, object: nil)
    }

    func setupBulkControls() {
        self.bulkControls.isHidden = true
        self.bulkControls.layer.cornerRadius = 13
        self.bulkControls.layer.shadowOpacity = 0.3
        self.bulkControls.layer.shadowRadius = 5
        self.bulkControls.layer.shadowOffset = .zero

        self.bulkControls.onSortTap = {
            self.present(self.sortDialog(), animated: true, completion: nil)
        }

        self.bulkControls.onMoveTap = {
            guard let indexPaths = self.tableView.indexPathsForSelectedRows else {
                return
            }

            let selectedItems = indexPaths.map { (indexPath) -> LibraryItem in
                return self.items[indexPath.row]
            }

            self.handleMove(selectedItems)
        }

        self.bulkControls.onDeleteTap = {
            guard let indexPaths = self.tableView.indexPathsForSelectedRows else {
                return
            }

            let selectedItems = indexPaths.map { (indexPath) -> LibraryItem in
                return self.items[indexPath.row]
            }

            self.handleTrash(selectedItems)
        }
    }

    func deleteRows(at indexPaths: [IndexPath]) {
        self.tableView.beginUpdates()
        self.tableView.deleteRows(at: indexPaths, with: .none)
        self.tableView.endUpdates()
        self.toggleEmptyStateView()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        self.bulkControls.moveButton.isEnabled = false
        self.bulkControls.trashButton.isEnabled = false

        let notification: Notification.Name = !editing ? .playerDismissed : .playerPresented

        self.animateView(self.bulkControls, show: editing)
        self.tableView.setEditing(editing, animated: true)

        NotificationCenter.default.post(name: notification, object: nil, userInfo: nil)
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

        UIApplication.shared.isIdleTimerDisabled = true

        self.present(providerList, animated: true, completion: nil)
    }

    func showPlayerView(book: Book) {
        let storyboard = UIStoryboard(name: "Player", bundle: nil)

        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            playerVC.currentBook = book

            self.present(playerVC, animated: true)
        }
    }

    func setupPlayer(book: Book) {
        // Make sure player is for a different book
        guard
            let currentBook = PlayerManager.shared.currentBook,
            currentBook == book
        else {
            // Handle loading new player
            self.loadPlayer(book: book)

            return
        }

        self.showPlayerView(book: currentBook)
    }

    func loadPlayer(book: Book) {
        guard DataManager.exists(book) else {
            self.showAlert("File missing!", message: "This book’s file was removed from your device. Import the file again to play the book")

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

    func handleOperationCompletion(_ files: [FileItem]) {
        fatalError("handleOperationCompletion must be overriden")
    }

    func presentCreatePlaylistAlert(_ namePlaceholder: String = "New Playlist", handler: ((_ title: String) -> Void)?) {
        let playlistAlert = self.createPlaylistAlert(namePlaceholder, handler: handler)

        let vc = presentedViewController ?? self

        vc.present(playlistAlert, animated: true) {
            guard let textfield = playlistAlert.textFields?.first else { return }
            textfield.becomeFirstResponder()
            textfield.selectedTextRange = textfield.textRange(from: textfield.beginningOfDocument, to: textfield.endOfDocument)
        }
    }

    func sort(by sortType: PlayListSortOrder) {}

    func handleMove(_ selectedItems: [LibraryItem]) {}

    func handleTrash(_ selectedItems: [LibraryItem]) {}

    func handleDelete(books: [Book]) {
        let alert = UIAlertController(title: "Do you want to delete \(books.count) books?", message: nil, preferredStyle: .alert)

        if books.count == 1, let book = books.first {
            alert.title = "Do you want to delete “\(book.title!)”?"
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.delete(books, mode: .deep)
        }))

        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(x: Double(view.bounds.size.width / 2.0), y: Double(view.bounds.size.height - 45), width: 1.0, height: 1.0)

        present(alert, animated: true, completion: nil)
    }

    func createOptionsSheetController(_ item: LibraryItem) -> UIAlertController {
        let sheet = UIAlertController(title: item.title, message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Rename", style: .default) { _ in
            let alert = self.renameItemAlert(item)

            self.present(alert, animated: true, completion: nil)
        })

        sheet.addAction(UIAlertAction(title: "Move", style: .default, handler: { _ in
            self.handleMove([item])
        }))

        if let book = item as? Book {
            sheet.addAction(UIAlertAction(title: "Export", style: .default, handler: { _ in
                let shareController = self.createExportController(book)

                self.present(shareController, animated: true, completion: nil)
            }))
        }

        sheet.addAction(UIAlertAction(title: "Jump To Start", style: .default, handler: { _ in
            DataManager.jumpToStart(item)
            self.reloadData()
        }))

        let markTitle = item.isFinished ? "Mark as Unfinished" : "Mark as Finished"

        sheet.addAction(UIAlertAction(title: markTitle, style: .default, handler: { _ in
            DataManager.mark(item, asFinished: !item.isFinished)
            self.reloadData()
        }))

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        return sheet
    }
}

// MARK: - Callback events

extension ItemListViewController {
    @objc func reloadData() {
        CATransaction.begin()
        if self.isEditing {
            CATransaction.setCompletionBlock {
                self.isEditing = false
            }
        }
        self.tableView.beginUpdates()
        self.tableView.reloadSections(IndexSet(integer: Section.data.rawValue), with: .none)
        self.tableView.endUpdates()
        CATransaction.commit()
        self.toggleEmptyStateView()
    }

    @objc func bookReady() {
        self.tableView.reloadData()
    }

    @objc func onBookPlay() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let fileURL = currentBook.fileURL,
            let index = self.library.itemIndex(with: fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .playing
    }

    @objc func onBookPause() {
        guard
            let book = PlayerManager.shared.currentBook,
            let fileURL = book.fileURL,
            let index = self.library.itemIndex(with: fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
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
            let fileURL = book.fileURL,
            let index = self.library.itemIndex(with: fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .stopped
    }

    @objc func updateProgress(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL else {
            return
        }

        guard let index = (self.items.firstIndex { (item) -> Bool in
            if let book = item as? Book {
                return book.fileURL == fileURL
            }

            if let playlist = item as? Playlist {
                return playlist.getBook(with: fileURL) != nil
            }

            return false
        }), let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView else {
            return
        }

        let item = self.items[index]

        let progress = item is Playlist
            ? item.progress
            : userInfo["progress"] as? Double ?? item.progress

        cell.progress = item.isFinished ? 1.0 : progress
    }

    @objc func adjustBottomOffsetForMiniPlayer() {
        if let rootViewController = self.parent?.parent as? RootViewController {
            self.tableView.contentInset.bottom = rootViewController.miniPlayerIsHidden ? 0.0 : 88.0
        }
    }
}

// MARK: - Feedback

extension ItemListViewController: ItemListFeedback {
    func showLoadView(_ show: Bool, title: String? = nil, subtitle: String? = nil) {
        if let title = title {
            self.loadingView.titleLabel.text = title
        }

        if let subtitle = subtitle {
            self.loadingView.subtitleLabel.text = subtitle
            self.loadingView.subtitleLabel.isHidden = false
        } else {
            self.loadingView.subtitleLabel.isHidden = true
        }

        // verify there's something to do
        guard self.loadingView.isHidden == show else {
            return
        }

        self.loadingHeightConstraintView.constant = show
            ? 65
            : 0
        UIView.animate(withDuration: 0.5) {
            self.loadingView.isHidden = !show
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - TableView DataSource

extension ItemListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == Section.data.rawValue
            ? self.items.count
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

        let item = self.items[indexPath.row]

        cell.artwork = item.artwork
        cell.title = item.title
        cell.playbackState = .stopped
        cell.type = item is Playlist ? .playlist : .book

        cell.onArtworkTap = { [weak self] in
            guard !tableView.isEditing else {
                if cell.isSelected {
                    tableView.deselectRow(at: indexPath, animated: true)
                    self?.tableView(tableView, didDeselectRowAt: indexPath)
                } else {
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                    self?.tableView(tableView, didSelectRowAt: indexPath)
                }
                return
            }

            guard let book = self?.getNextBook(item) else { return }

            self?.setupPlayer(book: book)
        }

        if let book = item as? Book {
            cell.subtitle = book.author
        } else if let playlist = item as? Playlist {
            cell.subtitle = playlist.info()
        }

        cell.progress = item.isFinished ? 1.0 : item.progress

        return cell
    }

    func getNextBook(_ item: LibraryItem) -> Book? {
        guard let playlist = item as? Playlist else {
            return item.getBookToPlay()
        }

        // Special treatment for playlists
        guard
            let bookPlaying = PlayerManager.shared.currentBook,
            let currentPlaylist = bookPlaying.playlist,
            currentPlaylist == playlist else {
            // restart the selected playlist if current playing book has no relation to it
            if item.isFinished {
                DataManager.jumpToStart(item)
            }

            return item.getBookToPlay()
        }

        // override next book with the one already playing
        return bookPlaying
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.total.rawValue
    }
}

// MARK: - TableView Delegate

extension ItemListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.sectionValue == .data
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard tableView.isEditing else { return indexPath }

        guard indexPath.sectionValue == .data else { return nil }

        return indexPath
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.bulkControls.moveButton.isEnabled = true
        self.bulkControls.trashButton.isEnabled = true
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard tableView.indexPathForSelectedRow == nil else {
            return
        }

        self.bulkControls.moveButton.isEnabled = false
        self.bulkControls.trashButton.isEnabled = false
    }
}

// MARK: - Reorder Delegate

extension ItemListViewController: TableViewReorderDelegate {
    func tableViewDidBeginReordering(_ tableView: UITableView, at indexPath: IndexPath) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func tableView(_ tableView: UITableView, canReorderRowAt indexPath: IndexPath) -> Bool {
        return indexPath.sectionValue == .data
    }

    func tableView(_ tableView: UITableView, targetIndexPathForReorderFromRowAt sourceIndexPath: IndexPath, to proposedDestinationIndexPath: IndexPath, snapshot: UIView?) -> IndexPath {
        guard proposedDestinationIndexPath.sectionValue == .data else {
            return sourceIndexPath
        }

        if let snapshot = snapshot {
            UIView.animate(withDuration: 0.2) {
                snapshot.transform = CGAffineTransform.identity
            }
        }

        return proposedDestinationIndexPath
    }

    @objc func tableView(_ tableView: UITableView, sourceIndexPath: IndexPath, overIndexPath: IndexPath, snapshot: UIView) {
        guard overIndexPath.sectionValue == .data else {
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let scale: CGFloat = 0.90

        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: {
            snapshot.transform = CGAffineTransform(scaleX: scale, y: scale)
        })
    }

    @objc func tableViewDidFinishReordering(_ tableView: UITableView, from initialSourceIndexPath: IndexPath, to finalDestinationIndexPath: IndexPath, dropped overIndexPath: IndexPath?) {
        //
    }
}

// MARK: DocumentPicker Delegate

extension ItemListViewController: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // iOS 11+
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        UIApplication.shared.isIdleTimerDisabled = false
        for url in urls {
            DataManager.processFile(at: url)
        }
    }

    // support iOS 10
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        UIApplication.shared.isIdleTimerDisabled = false
        DataManager.processFile(at: url)
    }
}

extension ItemListViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.view.backgroundColor = theme.backgroundColor
        self.tableView.backgroundColor = theme.backgroundColor
        self.tableView.separatorColor = theme.separatorColor
        self.emptyStatePlaceholder.backgroundColor = theme.backgroundColor
        self.emptyStatePlaceholder.tintColor = theme.highlightColor
        self.bulkControls.backgroundColor = theme.backgroundColor
        self.bulkControls.tintColor = theme.highlightColor
        self.bulkControls.layer.shadowColor = theme.useDarkVariant
            ? UIColor.white.cgColor
            : UIColor(red: 0.12, green: 0.14, blue: 0.15, alpha: 1.0).cgColor
    }
}
