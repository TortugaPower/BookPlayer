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
    @IBOutlet weak var emptyStatePlaceholder: UIView!
    @IBOutlet weak var loadingContainerView: UIView!
    @IBOutlet weak var loadingTitleLabel: UILabel!
    @IBOutlet weak var loadingSubtitleLabel: UILabel!
    @IBOutlet weak var loadingHeightConstraintView: NSLayoutConstraint!
    @IBOutlet weak var bulkControlContainerView: UIView!
    @IBOutlet weak var moveButton: UIButton!
    @IBOutlet weak var trashButton: UIButton!

    @IBOutlet weak var tableView: UITableView!

    var library: Library!

    // TableView's datasource
    var items: [LibraryItem] {
        guard self.library != nil else {
            return []
        }

        return self.library.items?.array as? [LibraryItem] ?? []
    }

    // keep in memory current Documents folder
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupBulkControls()

        self.navigationItem.rightBarButtonItem = self.editButtonItem

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

        NotificationCenter.default.addObserver(self, selector: #selector(self.bookReady), name: .bookReady, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateProgress(_:)), name: .updatePercentage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.adjustBottomOffsetForMiniPlayer), name: .playerPresented, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.adjustBottomOffsetForMiniPlayer), name: .playerDismissed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: .bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: .bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookStop(_:)), name: .bookStopped, object: nil)
    }

    func setupBulkControls() {
        self.bulkControlContainerView.layer.cornerRadius = 10
        self.bulkControlContainerView.layer.shadowColor = UIColor.black.cgColor
        self.bulkControlContainerView.layer.shadowOpacity = 0.3
        self.bulkControlContainerView.layer.shadowRadius = 5
        self.bulkControlContainerView.layer.shadowOffset = .zero
        self.bulkControlContainerView.isHidden = true
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        self.moveButton.isEnabled = false
        self.trashButton.isEnabled = false

        let notification: Notification.Name = !editing ? .playerDismissed : .playerPresented

        self.bulkControlContainerView.isHidden = !editing
        self.tableView.setEditing(editing, animated: true)

        NotificationCenter.default.post(name: notification, object: nil, userInfo: nil)
    }

    func showLoadView(_ show: Bool, subtitle: String) {
        self.showLoadView(show, title: nil, subtitle: subtitle)
    }

    func showLoadView(_ show: Bool, title: String? = nil, subtitle: String? = nil) {
        if let title = title {
            self.loadingTitleLabel.text = title
        }

        if let subtitle = subtitle {
            self.loadingSubtitleLabel.text = subtitle
            self.loadingSubtitleLabel.isHidden = false
        } else {
            self.loadingSubtitleLabel.isHidden = true
        }

        // verify there's something to do
        guard self.loadingContainerView.isHidden == show else {
            return
        }

        self.loadingHeightConstraintView.constant = show
            ? 65
            : 0
        UIView.animate(withDuration: 0.5) {
            self.loadingContainerView.isHidden = !show
            self.view.layoutIfNeeded()
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

    func deleteRows(at indexPaths: [IndexPath]) {
        self.tableView.beginUpdates()
        self.tableView.deleteRows(at: indexPaths, with: .none)
        self.tableView.endUpdates()
        self.toggleEmptyStateView()
    }

    // MARK: - IBActions

    @IBAction func didTapSort(_ sender: UIButton) {
        present(self.sortDialog(), animated: true, completion: nil)
    }

    @IBAction func didTapMove(_ sender: UIButton) {}

    @IBAction func didTapTrash(_ sender: UIButton) {}

    // MARK: - Callback events

    @objc func reloadData() {
        self.tableView.beginUpdates()
        self.tableView.reloadSections(IndexSet(integer: Section.library.rawValue), with: .none)
        self.tableView.endUpdates()
        self.toggleEmptyStateView()
    }

    @objc func bookReady() {
        self.tableView.reloadData()
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
            self.tableView.contentInset.bottom = rootViewController.miniPlayerIsHidden ? 0.0 : 88.0
        }
    }

    // MARK: - Sorting

    private func sortDialog() -> UIAlertController {
        let alert = UIAlertController(title: "Sort Files by", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Title", style: .default, handler: { _ in
            self.sort(by: .metadataTitle)
            self.tableView.reloadData()
        }))

        alert.addAction(UIAlertAction(title: "Original File Name", style: .default, handler: { _ in
            self.sort(by: .fileName)
            self.tableView.reloadData()
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        return alert
    }

    func sort(by sortType: PlayListSortOrder) {}
}

// MARK: - TableView DataSource

extension BaseListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == Section.library.rawValue
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

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.total.rawValue
    }
}

// MARK: - TableView Delegate

extension BaseListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.sectionValue == .library
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .none
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard tableView.isEditing else { return indexPath }

        guard indexPath.sectionValue == .library else { return nil }

        return indexPath
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.moveButton.isEnabled = true
        self.trashButton.isEnabled = true
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard tableView.indexPathForSelectedRow == nil else {
            return
        }

        self.moveButton.isEnabled = false
        self.trashButton.isEnabled = false
    }
}

// MARK: - Reorder Delegate

extension BaseListViewController: TableViewReorderDelegate {
    @objc func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {}

    func tableView(_ tableView: UITableView, canReorderRowAt indexPath: IndexPath) -> Bool {
        return indexPath.sectionValue == .library
    }

    func tableView(_ tableView: UITableView, targetIndexPathForReorderFromRowAt sourceIndexPath: IndexPath, to proposedDestinationIndexPath: IndexPath, snapshot: UIView?) -> IndexPath {
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

    func tableView(_ tableView: UITableView, sourceIndexPath: IndexPath, overIndexPath: IndexPath, snapshot: UIView) {
        guard overIndexPath.sectionValue == .library else {
            return
        }

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

extension BaseListViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            DataManager.processFile(at: url)
        }
    }
}
