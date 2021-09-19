//
//  FolderListViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import DeviceKit
import Themeable
import UIKit

class FolderListViewController: UIViewController, Storyboarded {
  @IBOutlet weak var emptyStatePlaceholder: UIView!
  @IBOutlet weak var loadingView: LoadingView!
  @IBOutlet weak var loadingHeightConstraintView: NSLayoutConstraint!
  @IBOutlet weak var bulkControls: BulkControlsView!
  @IBOutlet weak var bulkControlsBottomConstraint: NSLayoutConstraint!

  @IBOutlet weak var tableView: UITableView!

  private var previousLeftButtons: [UIBarButtonItem]?
  lazy var selectButton: UIBarButtonItem = UIBarButtonItem(title: "select_all_title".localized, style: .plain, target: self, action: #selector(selectButtonPressed))

  var viewModel: FolderListViewModel!
  var dataSource: ItemListTableDataSource!

  private var disposeBag = Set<AnyCancellable>()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.configureDataSource()
    self.bindDataItems()
    self.configureInitialState()
  }

  func configureInitialState() {
    self.adjustBottomOffsetForMiniPlayer()

    self.navigationItem.rightBarButtonItem = self.editButtonItem

    self.showLoadView(false)

    self.navigationItem.title = self.viewModel.folder.title

    // Remove the line after the last cell
    self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: 1))

    // Fixed tableview having strange offset
    self.edgesForExtendedLayout = UIRectEdge()

    self.setUpTheming()

    self.setupBulkControls()

    let interaction = UIDropInteraction(delegate: self)
    self.view.addInteraction(interaction)
  }

  func configureDataSource() {
    self.tableView.register(UINib(nibName: "BookCellView", bundle: nil), forCellReuseIdentifier: "BookCellView")
    self.tableView.register(UINib(nibName: "AddCellView", bundle: nil), forCellReuseIdentifier: "AddCellView")

    self.tableView.rowHeight = UITableView.automaticDimension
    self.tableView.estimatedRowHeight = UITableView.automaticDimension
    self.tableView.allowsSelection = true
    self.tableView.allowsMultipleSelectionDuringEditing = true
    self.tableView.dragInteractionEnabled = true
    self.tableView.dragDelegate = self
    self.tableView.dropDelegate = self

    self.dataSource = ItemListTableDataSource(tableView: tableView) { (tableView, indexPath, item) -> UITableViewCell? in
      guard indexPath.sectionValue != .add,
          let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as? BookCellView else {
          return tableView.dequeueReusableCell(withIdentifier: "AddCellView", for: indexPath)
      }

      cell.title = item.title
      cell.subtitle = item.details
      cell.progress = item.progress
      cell.duration = item.duration
      cell.type = item.type
      cell.playbackState = item.playbackState

      if let data = item.artworkData {
        cell.artwork = UIImage(data: data)
      } else {
        cell.artwork = nil
      }

      return cell
    }

    self.updateSnapshot(with: self.viewModel.getInitialItems(), animated: false)
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    guard self.traitCollection.userInterfaceStyle != .unspecified else { return }

    ThemeManager.shared.checkSystemMode()
  }

  func adjustBottomOffsetForMiniPlayer() {
    self.tableView.contentInset.bottom = self.viewModel.getMiniPlayerOffset()
  }

  func setupBulkControls() {
    self.bulkControlsBottomConstraint.constant = Device.current.hasSensorHousing ? 136: 25
    self.bulkControls.isHidden = true
    self.bulkControls.layer.cornerRadius = 13
    self.bulkControls.layer.shadowOpacity = 0.3
    self.bulkControls.layer.shadowRadius = 5
    self.bulkControls.layer.shadowOffset = .zero

    self.bulkControls.onSortTap = {
      // TODO: handle sort
    }

    self.bulkControls.onMoveTap = {
      guard let indexPaths = self.tableView.indexPathsForSelectedRows else {
        return
      }

      // TODO: handle move
      let selectedItems = indexPaths.map({ self.dataSource.itemIdentifier(for: $0) })
    }

    self.bulkControls.onDeleteTap = {
      guard let indexPaths = self.tableView.indexPathsForSelectedRows else {
        return
      }

      // TODO: handle delete
      let selectedItems = indexPaths.map({ self.dataSource.itemIdentifier(for: $0) })
    }

    self.bulkControls.onMoreTap = {
      guard let indexPaths = self.tableView.indexPathsForSelectedRows else {
        return
      }

      // TODO: handle more action
      let selectedItems = indexPaths.map({ self.dataSource.itemIdentifier(for: $0) })
    }
  }

  func bindDataItems() {
    self.viewModel.items.sink { [weak self] items in
      self?.updateSnapshot(with: items, animated: true)
    }
    .store(in: &disposeBag)

    self.dataSource.reorderUpdates.sink { [weak self] (item, sourceIndexPath, destinationIndexPath) in
      self?.viewModel.reorder(item: item, sourceIndexPath: sourceIndexPath, destinationIndexPath: destinationIndexPath)
    }
    .store(in: &disposeBag)

    self.viewModel.coordinator.onTransition = { route in
      switch route {
      case .importOptions:
        self.viewModel.showAddActions()
      case .importLocalFiles:
        self.viewModel.coordinator.showDocumentPicker(in: self)
      case .newImportOperation(let operation):
        let loadingTitle = String.localizedStringWithFormat("import_processing_description".localized, operation.files.count)
        self.showLoadView(true, title: loadingTitle)
      case .importOperationFinished(let files):
        self.showLoadView(false)
        self.viewModel.handleOperationCompletion(files)
      case .createFolder(let title, let items):
        self.viewModel.createFolder(with: title, items: items)
      case .insertIntoLibrary(let items):
        self.viewModel.handleInsertionIntoLibrary(items)
      }
    }
  }

  override func setEditing(_ editing: Bool, animated: Bool) {
    super.setEditing(editing, animated: animated)

    self.viewModel.showMiniPlayer(!editing)

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
  }

  func updateSnapshot(with items: [SimpleLibraryItem], animated: Bool) {
    self.toggleEmptyStateView()

    var snapshot = NSDiffableDataSourceSnapshot<SectionType, SimpleLibraryItem>()
    snapshot.appendSections([.data])
    snapshot.appendItems(items, toSection: .data)
    snapshot.appendSections([.add])
    snapshot.appendItems([SimpleLibraryItem()], toSection: .add)
    self.dataSource.apply(snapshot, animatingDifferences: false)
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

  @IBAction func addAction() {
    self.viewModel.showAddActions()
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

extension FolderListViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    guard indexPath.sectionValue == .data else { return 66 }

    return UITableView.automaticDimension
  }

  func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    guard indexPath.sectionValue == .data,
          indexPath.row == (self.viewModel.items.value.count - 1) else { return }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      self.viewModel.loadNextItems()
    }
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
        self.viewModel.showAddActions()
      }

      return
    }

    guard let item = self.dataSource.itemIdentifier(for: indexPath) else {
      return
    }

    self.viewModel.showItemContents(item)
  }
}

extension FolderListViewController: UITableViewDragDelegate {
  func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    return [UIDragItem(itemProvider: NSItemProvider())]
  }
}

extension FolderListViewController: UITableViewDropDelegate {
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

extension FolderListViewController: UIDropInteractionDelegate {
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

// MARK: DocumentPicker Delegate

extension FolderListViewController: UIDocumentPickerDelegate {
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    UIApplication.shared.isIdleTimerDisabled = false
  }

  // iOS 11+
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    UIApplication.shared.isIdleTimerDisabled = false
    self.viewModel.handleNewFiles(urls)
  }

  // support iOS 10
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
    UIApplication.shared.isIdleTimerDisabled = false
    self.viewModel.handleNewFiles([url])
  }
}

// MARK: - Feedback

extension FolderListViewController {
  func toggleEmptyStateView() {
    self.emptyStatePlaceholder.isHidden = !self.viewModel.items.value.isEmpty
    self.editButtonItem.isEnabled = !self.viewModel.items.value.isEmpty
  }

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

// MARK: - Themeable

extension FolderListViewController: Themeable {
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

    self.viewModel.updateDefaultArtwork(for: theme)
  }
}
