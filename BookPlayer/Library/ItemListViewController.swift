//
//  ItemListViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import MediaPlayer
import Themeable
import UIKit

// swiftlint:disable file_length

class ItemListViewController: UIViewController, ItemList, ItemListAlerts, ItemListActions, TelemetryProtocol, Storyboarded {
  weak var coordinator: ItemListCoordinator?

    @IBOutlet weak var emptyStatePlaceholder: UIView!
    @IBOutlet weak var loadingView: LoadingView!
    @IBOutlet weak var loadingHeightConstraintView: NSLayoutConstraint!
    @IBOutlet weak var bulkControls: BulkControlsView!

    @IBOutlet weak var tableView: UITableView!

    private var previousLeftButtons: [UIBarButtonItem]?
    lazy var selectButton: UIBarButtonItem = UIBarButtonItem(title: "select_all_title".localized, style: .plain, target: self, action: #selector(selectButtonPressed))

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
        self.tableView.dragInteractionEnabled = true
        self.tableView.dragDelegate = self
        self.tableView.dropDelegate = self

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

        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = UITableView.automaticDimension

        let interaction = UIDropInteraction(delegate: self)
        self.view.addInteraction(interaction)
    }

    func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateProgress(_:)), name: .bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.adjustBottomOffsetForMiniPlayer), name: .playerPresented, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.adjustBottomOffsetForMiniPlayer), name: .playerDismissed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: .bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: .bookPaused, object: nil)
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
                self.items[indexPath.row]
            }

            self.handleMove(selectedItems)
        }

        self.bulkControls.onDeleteTap = {
            guard let indexPaths = self.tableView.indexPathsForSelectedRows else {
                return
            }

            let selectedItems = indexPaths.map { (indexPath) -> LibraryItem in
                self.items[indexPath.row]
            }

            self.handleTrash(selectedItems)
        }

        self.bulkControls.onMoreTap = {
            guard let indexPaths = self.tableView.indexPathsForSelectedRows else {
                return
            }

            let selectedItems = indexPaths.map { (indexPath) -> LibraryItem in
                self.items[indexPath.row]
            }

            guard let sheet = self.createOptionsSheetController(selectedItems) else { return }

            self.present(sheet, animated: true, completion: nil)
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

        let notification: Notification.Name = !editing ? .playerDismissed : .playerPresented

        if let mainCoordinator = self.coordinator?.parentCoordinator as? MainCoordinator {
          mainCoordinator.showMiniPlayer(!editing)
        }

        self.animateView(self.bulkControls, show: editing)
        self.tableView.setEditing(editing, animated: true)

        if editing {
            self.previousLeftButtons = navigationItem.leftBarButtonItems
            self.navigationItem.leftBarButtonItems = [self.selectButton]
            self.selectButton.isEnabled = self.tableView.numberOfRows(inSection: Section.data.rawValue) > 0
            self.updateSelectionStatus()
        } else {
            self.navigationItem.leftBarButtonItems = self.previousLeftButtons
        }

        NotificationCenter.default.post(name: notification, object: nil, userInfo: nil)
    }

    func updateSelectionStatus() {
        guard self.tableView.isEditing else { return }

        self.selectButton.title = self.tableView.numberOfRows(inSection: Section.data.rawValue) > (self.tableView.indexPathsForSelectedRows?.count ?? 0)
            ? "select_all_title".localized
            : "deselect_all_title".localized

        guard self.tableView.indexPathForSelectedRow == nil else {
            self.bulkControls.moveButton.isEnabled = true
            self.bulkControls.trashButton.isEnabled = true
            self.bulkControls.moreButton.isEnabled = true
            return
        }

        self.bulkControls.moveButton.isEnabled = false
        self.bulkControls.trashButton.isEnabled = false
        self.bulkControls.moreButton.isEnabled = false
    }

    func toggleEmptyStateView() {
        self.emptyStatePlaceholder.isHidden = !self.items.isEmpty
        self.editButtonItem.isEnabled = !self.items.isEmpty
    }

    func presentAddOptionsAlert() {}

    func presentImportFilesAlert() {
        let providerList = UIDocumentPickerViewController(documentTypes: ["public.audio", "com.pkware.zip-archive", "public.movie"], in: .import)

        providerList.delegate = self
        providerList.allowsMultipleSelection = true

        UIApplication.shared.isIdleTimerDisabled = true

        self.present(providerList, animated: true, completion: nil)
    }

    func handleOperationCompletion(_ files: [URL]) {
        fatalError("handleOperationCompletion must be overriden")
    }

    func presentCreateFolderAlert(_ namePlaceholder: String = "new_playlist_button".localized, handler: ((_ title: String) -> Void)?) {
        let folderAlert = self.createFolderAlert(namePlaceholder, handler: handler)

        let vc = presentedViewController ?? self

        vc.present(folderAlert, animated: true) {
            guard let textfield = folderAlert.textFields?.first else { return }
            textfield.becomeFirstResponder()
            textfield.selectedTextRange = textfield.textRange(from: textfield.beginningOfDocument, to: textfield.endOfDocument)
        }
    }

    func sort(by sortType: PlayListSortOrder) {}

    func handleMove(_ selectedItems: [LibraryItem]) {}

    func handleTrash(_ selectedItems: [LibraryItem]) {}

    func handleDelete(items: [LibraryItem]) {
        let alert = UIAlertController(title: String.localizedStringWithFormat("delete_multiple_items_title".localized, items.count),
                                      message: "delete_multiple_items_description".localized,
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

        var deleteActionTitle = "delete_button".localized

        if items.count == 1, let folder = items.first as? Folder {
            deleteActionTitle = "delete_deep_button".localized

            alert.title = String(format: "delete_single_item_title".localized, folder.title!)
            alert.message = "delete_single_playlist_description".localized
            alert.addAction(UIAlertAction(title: "delete_shallow_button".localized, style: .default, handler: { _ in
              do {
                try self.delete(items, mode: .shallow)
              } catch {
                self.showAlert("error_title".localized, message: error.localizedDescription)
              }
            }))
        }

        alert.addAction(UIAlertAction(title: deleteActionTitle, style: .destructive, handler: { _ in
          do {
            try self.delete(items, mode: .deep)
          } catch {
            self.showAlert("error_title".localized, message: error.localizedDescription)
          }
        }))

        present(alert, animated: true, completion: nil)
    }

    func createOptionsSheetController(_ items: [LibraryItem]) -> UIAlertController? {
        guard let item = items.first else {
            return nil
        }

        let isSingle = items.count == 1

        let sheetTitle = isSingle ? item.title : "options_button".localized

        let sheet = UIAlertController(title: sheetTitle, message: nil, preferredStyle: .actionSheet)

        let renameAction = UIAlertAction(title: "rename_button".localized, style: .default) { _ in
            let alert = self.renameItemAlert(item)

            self.present(alert, animated: true, completion: nil)
        }

        renameAction.isEnabled = isSingle
        sheet.addAction(renameAction)

        sheet.addAction(UIAlertAction(title: "move_title".localized, style: .default, handler: { _ in
            self.handleMove(items)
        }))

        let exportAction = UIAlertAction(title: "export_button".localized, style: .default, handler: { _ in
            guard let shareController = self.createExportController(item) else { return }

            self.present(shareController, animated: true, completion: nil)
		})

        exportAction.isEnabled = isSingle && item is Book
        sheet.addAction(exportAction)

        sheet.addAction(UIAlertAction(title: "jump_start_title".localized, style: .default, handler: { _ in
            for item in items {
                DataManager.jumpToStart(item)
            }
            self.reloadData()
        }))

        let areFinished = !items.contains(where: { !$0.isFinished })
        let markTitle = areFinished ? "mark_unfinished_title".localized : "mark_finished_title".localized

        sheet.addAction(UIAlertAction(title: markTitle, style: .default, handler: { _ in
            for item in items {
                DataManager.mark(item, asFinished: !areFinished)
            }

            self.reloadData()
        }))

        sheet.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
        return sheet
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard self.traitCollection.userInterfaceStyle != .unspecified else { return }

        ThemeManager.shared.checkSystemMode()
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
        MPPlayableContentManager.shared().reloadData()
    }

  @objc func onBookPlay() {
    guard
      let currentBook = PlayerManager.shared.currentBook,
      let index = self.library.index(for: currentBook),
      let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
    else {
      return
    }

    bookCell.playbackState = .playing
  }

  @objc func onBookPause() {
    guard
      let book = PlayerManager.shared.currentBook,
      let index = self.library.index(for: book),
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
      let index = self.library.index(for: book),
      let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView
    else {
      return
    }

    bookCell.playbackState = .stopped
  }

    @objc func updateProgress(_ notification: Notification) {
      guard let userInfo = notification.userInfo,
            let currentBook = userInfo["book"] as? Book,
            let index = self.library.index(for: currentBook),
            let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: .data)) as? BookCellView else {
        return
      }

      let item = self.items[index]

      let progress = item is Folder
        ? item.progressPercentage
        : userInfo["progress"] as? Double ?? item.progressPercentage

      cell.progress = item.isFinished ? 1.0 : progress
    }

    @objc func adjustBottomOffsetForMiniPlayer() {
      if let cc = self.coordinator as? LibraryListCoordinator {
        self.tableView.contentInset.bottom = cc.miniPlayerOffset
      }
    }

    @objc func selectButtonPressed(_ sender: Any) {
        if self.tableView.numberOfRows(inSection: Section.data.rawValue) == (self.tableView.indexPathsForSelectedRows?.count ?? 0) {
            for row in 0..<self.tableView.numberOfRows(inSection: Section.data.rawValue) {
                self.tableView.deselectRow(at: IndexPath(row: row, section: .data), animated: true)
            }
        } else {
            for row in 0..<self.tableView.numberOfRows(inSection: Section.data.rawValue) {
                self.tableView.selectRow(at: IndexPath(row: row, section: .data), animated: true, scrollPosition: .none)
            }
        }

        self.updateSelectionStatus()
    }
}

// MARK: - Feedback

extension ItemListViewController: ItemListFeedback {
    func showLoadView(_ show: Bool, title: String? = nil, subtitle: String? = nil) {
        guard self.isViewLoaded else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [unowned self] in
                self.showLoadView(show, title: title, subtitle: subtitle)
            }
            return
        }

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
        guard indexPath.sectionValue != .add,
            let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as? BookCellView else {
            return tableView.dequeueReusableCell(withIdentifier: "AddCellView", for: indexPath)
        }

        let item = self.items[indexPath.row]

        cell.artwork = item.getArtwork(for: themeProvider.currentTheme)
        cell.title = item.title
        cell.playbackState = .stopped
        cell.type = item is Folder ? .folder : .book
        cell.showsReorderControl = true

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

          self?.coordinator?.loadPlayer(book)
        }

        if let book = item as? Book {
            cell.subtitle = book.author
        } else if let folder = item as? Folder {
            cell.subtitle = folder.info()
        }

        cell.progress = item.isFinished ? 1.0 : item.progressPercentage
        cell.duration = TimeParser.formatTotalDuration(item.duration)

        return cell
    }

    func getNextBook(_ item: LibraryItem) -> Book? {
        guard let folder = item as? Folder else {
            return item.getBookToPlay()
        }

        // Special treatment for folders
        guard
            let bookPlaying = PlayerManager.shared.currentBook,
            let currentFolder = bookPlaying.folder,
            currentFolder == folder else {
            // restart the selected folder if current playing book has no relation to it
            if item.isFinished {
                DataManager.jumpToStart(item)
            }

            return item.getBookToPlay()
        }

        // override next book with the one already playing
        return bookPlaying
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
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
        guard indexPath.sectionValue == .data else { return 66 }

        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard tableView.isEditing else { return indexPath }

        guard indexPath.sectionValue == .data else { return nil }

        return indexPath
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.updateSelectionStatus()

        guard !tableView.isEditing else {
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.sectionValue == .data else {
            if indexPath.sectionValue == .add {
                self.presentAddOptionsAlert()
            }

            return
        }

      self.coordinator?.showItemContents(self.items[indexPath.row])
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.updateSelectionStatus()
    }

  // MARK: - Reorder Delegate
  func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return indexPath.sectionValue == .data
  }

  func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    guard sourceIndexPath.sectionValue == .data,
          destinationIndexPath.sectionValue == .data,
          sourceIndexPath.row != destinationIndexPath.row  else {
        return
    }

    let item = self.items[sourceIndexPath.row]

    self.library.removeFromItems(at: sourceIndexPath.row)
    self.library.insertIntoItems(item, at: destinationIndexPath.row)

    DataManager.saveContext()
    MPPlayableContentManager.shared().reloadData()
  }
}

extension ItemListViewController: UITableViewDragDelegate {
  func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    return [UIDragItem(itemProvider: NSItemProvider())]
  }
}

extension ItemListViewController: UITableViewDropDelegate {
  func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {}

  func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
    // Cancel drop if destination is not in the data section
    if destinationIndexPath?.sectionValue == .add {
      return UITableViewDropProposal(operation: .cancel, intent: .unspecified)
    }

    if session.localDragSession != nil { // Drag originated from the same app.
      return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    return UITableViewDropProposal(operation: .cancel, intent: .unspecified)
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

extension ItemListViewController: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: ImportableItem.self)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {}

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        for item in session.items {
            self.handleDroppedItem(item)
        }
    }

    func handleDroppedItem(_ item: UIDragItem) {
        let providerReference = item.itemProvider

        item.itemProvider.loadObject(ofClass: ImportableItem.self) { (object, _) in
            guard let item = object as? ImportableItem else { return }
            item.suggestedName = providerReference.suggestedName

            DataManager.importData(from: item)
        }
    }
}

extension ItemListViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.view.backgroundColor = theme.systemBackgroundColor
        self.tableView.backgroundColor = theme.systemBackgroundColor
        self.tableView.separatorColor = theme.separatorColor
        self.emptyStatePlaceholder.backgroundColor = theme.systemBackgroundColor
        self.emptyStatePlaceholder.tintColor = theme.linkColor
        self.bulkControls.backgroundColor = theme.systemBackgroundColor
        self.bulkControls.tintColor = theme.linkColor
        self.bulkControls.layer.shadowColor = theme.useDarkVariant
            ? UIColor.white.cgColor
            : UIColor(red: 0.12, green: 0.14, blue: 0.15, alpha: 1.0).cgColor
    }
}
