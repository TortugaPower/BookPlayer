//
//  ItemListViewController.swift
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

class ItemListViewController: BaseViewController<ItemListCoordinator, ItemListViewModel>,
                              Storyboarded,
                              UIGestureRecognizerDelegate, BPLogger {

  @IBOutlet weak var emptyStatePlaceholder: UIView!
  @IBOutlet weak var emptyStateImageView: UIImageView!
  @IBOutlet weak var loadingView: LoadingView!
  @IBOutlet weak var loadingHeightConstraintView: NSLayoutConstraint!
  @IBOutlet weak var bulkControls: BulkControlsView!
  @IBOutlet weak var bulkControlsBottomConstraint: NSLayoutConstraint!

  @IBOutlet weak var tableView: UITableView!

  private var previousLeftButtons: [UIBarButtonItem]?
  lazy var selectButton: UIBarButtonItem = UIBarButtonItem(title: "select_all_title".localized, style: .plain, target: self, action: #selector(selectButtonPressed))

  var defaultArtwork: UIImage? {
    if let data = viewModel.defaultArtwork {
      return UIImage(data: data)
    }

    return nil
  }

  private var disposeBag = Set<AnyCancellable>()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.configureDataSource()
    self.bindDataItems()
    self.bindTransitionActions()
    self.configureInitialState()
    self.bindNetworkObserver()
  }

  func configureInitialState() {
    self.adjustBottomOffsetForMiniPlayer()

    self.navigationItem.rightBarButtonItem = self.editButtonItem

    if self.navigationController?.viewControllers.count == 1 {
      self.navigationController!.interactivePopGestureRecognizer!.delegate = self

      self.previousLeftButtons = navigationItem.leftBarButtonItems

      self.viewModel.notifyPendingFiles()
    }

    self.emptyStateImageView.image = UIImage(named: self.viewModel.getEmptyStateImageName())

    // VoiceOver
    self.setupCustomRotors()

    self.showLoadView(false)

    self.navigationItem.title = self.viewModel.getNavigationTitle()

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

    self.updateSnapshot(with: self.viewModel.loadInitialItems(), animated: false)
  }

  func bindNetworkObserver() {
    NotificationCenter.default.publisher(for: .downloadProgress)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] notification in
        guard let self = self,
              let userInfo = notification.userInfo,
              let progress = userInfo["progress"] as? String else {
                return
              }

        self.showLoadView(true, title: "downloading_file_title".localized, subtitle: "\("progress_title".localized) \(progress)%")
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .downloadEnd)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.showLoadView(false)
      }
      .store(in: &disposeBag)
  }

  func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
      return (navigationController?.viewControllers.count ?? 0) > 1
  }

  func adjustBottomOffsetForMiniPlayer() {
    self.tableView.contentInset.bottom = 88
  }

  func setupBulkControls() {
    self.bulkControls.isHidden = true
    self.bulkControls.layer.cornerRadius = 13
    self.bulkControls.layer.shadowOpacity = 0.3
    self.bulkControls.layer.shadowRadius = 5
    self.bulkControls.layer.shadowOffset = .zero

    self.bulkControls.onSortTap = { [weak self] in
      self?.viewModel.showSortOptions()
    }

    self.bulkControls.onMoveTap = { [weak self] in
      guard
        let self = self,
        let indexPaths = self.tableView.indexPathsForSelectedRows
      else {
        return
      }

      let selectedItems = indexPaths.compactMap({ self.viewModel.items[$0.row] })

      self.viewModel.showMoveOptions(selectedItems: selectedItems)
    }

    self.bulkControls.onDeleteTap = { [weak self] in
      guard
        let self = self,
        let indexPaths = self.tableView.indexPathsForSelectedRows
      else {
        return
      }

      let selectedItems = indexPaths.compactMap({ self.viewModel.items[$0.row] })

      self.viewModel.showDeleteOptions(selectedItems: selectedItems)
    }

    self.bulkControls.onMoreTap = { [weak self] in
      guard
        let self = self,
        let indexPaths = self.tableView.indexPathsForSelectedRows
      else {
        return
      }

      let selectedItems = indexPaths.compactMap({ self.viewModel.items[$0.row] })

      self.viewModel.showMoreOptions(selectedItems: selectedItems)
    }
  }

  func bindDataItems() {
    self.viewModel.itemsUpdates.sink { [weak self] items in
      self?.updateSnapshot(with: items, animated: true)
    }
    .store(in: &disposeBag)

    self.viewModel.itemProgressUpdates.sink { [weak self] indexPath in
      self?.tableView.reloadRows(at: [indexPath], with: .none)
    }
    .store(in: &disposeBag)
  }

  func bindTransitionActions() {
    self.viewModel.coordinator.onAction = { [weak self] route in
      self?.setEditing(false, animated: false)

      switch route {
      case .importOptions:
        self?.viewModel.showAddActions()
      case .importLocalFiles:
        self?.viewModel.coordinator.showDocumentPicker()
      case .newImportOperation(let operation):
        let loadingTitle = String.localizedStringWithFormat("import_processing_description".localized, operation.files.count)
        self?.showLoadView(true, title: loadingTitle)
      case .importOperationFinished(let files):
        self?.showLoadView(false)
        self?.viewModel.handleOperationCompletion(files)
      case .importIntoFolder(let selectedFolder, let items, let type):
        self?.viewModel.importIntoFolder(selectedFolder, items: items, type: type)
      case .createFolder(let title, let items, let type):
        self?.viewModel.createFolder(with: title, items: items, type: type)
      case .updateFolders(let folders, let type):
        self?.viewModel.updateFolders(folders, type: type)
      case .moveIntoLibrary(let items):
        self?.viewModel.handleMoveIntoLibrary(items: items)
      case .moveIntoFolder(let selectedFolder, let items):
        self?.viewModel.handleMoveIntoFolder(selectedFolder, items: items)
      case .insertIntoLibrary(let items):
        self?.viewModel.handleInsertionIntoLibrary(items)
      case .delete(let items, let mode):
        self?.viewModel.handleDelete(items: items, mode: mode)
      case .sortItems(let option):
        self?.viewModel.handleSort(by: option)
      case .rename(let item, let newTitle):
        self?.viewModel.handleRename(item: item, with: newTitle)
      case .resetPlaybackPosition(let items):
        self?.viewModel.handleResetPlaybackPosition(for: items)
      case .markAsFinished(let items, let flag):
        self?.viewModel.handleMarkAsFinished(for: items, flag: flag)
      case .downloadBook(let url):
        self?.showLoadView(true, title: "downloading_file_title".localized, subtitle: "\("progress_title".localized) 0%")
        self?.viewModel.handleDownload(url)
      case .reloadItems(let pageSizePadding):
        self?.viewModel.reloadItems(pageSizePadding: pageSizePadding)
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

    var selectedIndexPaths: [IndexPath]?
    if self.isEditing {
      selectedIndexPaths = self.tableView.indexPathsForSelectedRows
    }

    self.tableView.reloadData()

    selectedIndexPaths?.forEach({ self.tableView.selectRow(at: $0, animated: false, scrollPosition: .none) })
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
    self.viewModel.loadAllItemsIfNeeded()

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

extension ItemListViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return Section.allCases.count
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard section == SectionType.data.rawValue else { return 1 }

    return self.viewModel.items.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard indexPath.sectionValue != .add,
          let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as? BookCellView else {
            return tableView.dequeueReusableCell(withIdentifier: "AddCellView", for: indexPath)
          }

    let item = self.viewModel.items[indexPath.row]

    cell.onArtworkTap = { [weak self] in
      guard !tableView.isEditing else {
        if cell.isSelected {
          tableView.deselectRow(at: indexPath, animated: true)
        } else {
          tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
        return
      }

      self?.viewModel.playNextBook(in: item)
    }

    cell.title = item.title
    cell.subtitle = item.details
    cell.progress = item.isFinished ? 1.0 : item.progress
    cell.duration = item.durationFormatted
    cell.type = item.type
    cell.playbackState = viewModel.getPlaybackState(for: item)

    cell.artworkView.kf.setImage(
      with: ArtworkService.getArtworkProvider(for: item.relativePath),
      placeholder: self.defaultArtwork,
      options: [.targetCache(ArtworkService.cache)]
    )
    cell.setAccessibilityLabels()
    return cell
  }
}

extension ItemListViewController: UITableViewDelegate {
  // MARK: reordering support

  func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return indexPath.sectionValue == .data
  }

  func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    guard sourceIndexPath.sectionValue == .data,
          destinationIndexPath.sectionValue == .data,
          sourceIndexPath.row != destinationIndexPath.row else {
        return
    }

    let item = self.viewModel.items[sourceIndexPath.row]
    self.viewModel.reorder(item: item, sourceIndexPath: sourceIndexPath, destinationIndexPath: destinationIndexPath)
  }

  // MARK: editing support

  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return indexPath.sectionValue == .data
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    guard indexPath.sectionValue == .data else { return 66 }

    return UITableView.automaticDimension
  }

  func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    guard indexPath.sectionValue == .data,
          indexPath.row == (self.viewModel.items.count - 1) else { return }

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

    let item = self.viewModel.items[indexPath.row]
    self.viewModel.showItemContents(item)
  }

  func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard indexPath.sectionValue == .data else { return nil }

    let item = self.viewModel.items[indexPath.row]

    let optionsAction = UIContextualAction(style: .normal, title: "\("options_button".localized)…") { _, _, completion in
      self.viewModel.showMoreOptions(selectedItems: [item])
      completion(true)
    }

    return UISwipeActionsConfiguration(actions: [optionsAction])
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

    item.itemProvider.loadObject(ofClass: ImportableItem.self) { [weak self] (object, _) in
      guard let item = object as? ImportableItem else { return }
      item.suggestedName = providerReference.suggestedName

      self?.viewModel.importData(from: item)
    }
  }
}

// MARK: DocumentPicker Delegate

extension ItemListViewController: UIDocumentPickerDelegate {
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    UIApplication.shared.isIdleTimerDisabled = false
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    UIApplication.shared.isIdleTimerDisabled = false
    self.viewModel.handleNewFiles(urls)
  }
}

// MARK: - Feedback

extension ItemListViewController {
  func toggleEmptyStateView() {
    self.emptyStatePlaceholder.isHidden = !self.viewModel.items.isEmpty
    self.editButtonItem.isEnabled = !self.viewModel.items.isEmpty
  }

  func showLoadView(_ show: Bool, title: String? = nil, subtitle: String? = nil) {
    guard self.isViewLoaded else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.showLoadView(show, title: title, subtitle: subtitle)
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

// MARK: Accessibility

extension ItemListViewController {
  private func setupCustomRotors() {
    self.accessibilityCustomRotors = [self.rotorFactory(name: "Books", type: .book), self.rotorFactory(name: "Folders", type: .folder)]
  }

  private func rotorFactory(name: String, type: SimpleItemType) -> UIAccessibilityCustomRotor {
    return UIAccessibilityCustomRotor(name: name) { [weak self] (predicate) -> UIAccessibilityCustomRotorItemResult? in

      guard
        let self = self,
        let cell = predicate.currentItem.targetElement as? BookCellView,
        let indexPath = self.tableView.indexPath(for: cell)
      else { return nil }

      // Load all items just in case
      self.viewModel.loadAllItemsIfNeeded()

      let newIndex = predicate.searchDirection == .next
      ? self.viewModel.getItem(of: type, after: indexPath.row)
      : self.viewModel.getItem(of: type, before: indexPath.row)

      guard let foundIndex = newIndex else { return nil }

      let newIndexPath = IndexPath(row: foundIndex, section: .data)

      self.tableView.scrollToRow(at: newIndexPath, at: .none, animated: false)
      let newCell = self.tableView.cellForRow(at: newIndexPath)!

      return UIAccessibilityCustomRotorItemResult(targetElement: newCell, targetRange: nil)
    }
  }
}

// MARK: - Themeable

extension ItemListViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
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
