//
//  FolderListViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit

class FolderListViewController: UIViewController, Storyboarded {
  @IBOutlet weak var emptyStatePlaceholder: UIView!
  @IBOutlet weak var loadingView: LoadingView!
  @IBOutlet weak var loadingHeightConstraintView: NSLayoutConstraint!
  @IBOutlet weak var bulkControls: BulkControlsView!

  @IBOutlet weak var tableView: UITableView!

  var coordinator: FolderListCoordinator!
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

    // Remove the line after the last cell
    self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: 1))

    // Fixed tableview having strange offset
    self.edgesForExtendedLayout = UIRectEdge()

    self.setUpTheming()
  }

  func configureDataSource() {
    self.tableView.register(UINib(nibName: "BookCellView", bundle: nil), forCellReuseIdentifier: "BookCellView")
    self.tableView.register(UINib(nibName: "AddCellView", bundle: nil), forCellReuseIdentifier: "AddCellView")

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
    self.tableView.contentInset.bottom = self.coordinator.miniPlayerOffset
  }

  func bindDataItems() {
    self.viewModel.items.sink { [weak self] items in
      self?.updateSnapshot(with: items, animated: true)
    }
    .store(in: &disposeBag)
  }

  func updateSnapshot(with items: [SimpleLibraryItem], animated: Bool) {
    self.toggleEmptyStateView()

    var snapshot = NSDiffableDataSourceSnapshot<SectionType, SimpleLibraryItem>()
    snapshot.appendSections([.data])
    snapshot.appendItems(items, toSection: .data)
    snapshot.appendSections([.add])
    snapshot.appendItems([SimpleLibraryItem()], toSection: .add)
    self.dataSource.apply(snapshot)
  }

  @IBAction func addAction() {
    //
  }
}

extension FolderListViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    guard indexPath.sectionValue == .data,
          indexPath.row == (self.viewModel.items.value.count - 1) else { return }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      self.viewModel.loadNextItems()
    }
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
