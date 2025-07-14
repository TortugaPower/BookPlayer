//
//  BookmarksViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit

class BookmarksViewController: UITableViewController, MVVMControllerProtocol, Storyboarded {
  var viewModel: BookmarksViewModel!
  private var disposeBag = Set<AnyCancellable>()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "bookmarks_title".localized

    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      image: ImageIcons.navigationBackImage,
      style: .plain,
      target: self,
      action: #selector(self.didPressClose)
    )
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      image: ImageIcons.share,
      style: .plain,
      target: self,
      action: #selector(self.didPressExport)
    )

    self.tableView.tableFooterView = UIView()
    self.tableView.rowHeight = UITableView.automaticDimension
    self.tableView.estimatedRowHeight = 55.66
    self.tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "Header")

    self.reloadData()

    setUpTheming()
    viewModel.reloadDataPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.reloadData()
      }
      .store(in: &disposeBag)
    viewModel.bindCurrentItemObserver()
  }

  func reloadData() {
    self.tableView.reloadData()
  }

  @IBAction func done(_ sender: UIBarButtonItem?) {
    self.viewModel.dismiss()
  }

  @objc func didPressClose() {
    viewModel.dismiss()
  }

  @objc func didPressExport() {
    viewModel.showExportController()
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }

  override func tableView(
    _ tableView: UITableView,
    viewForHeaderInSection section: Int
  ) -> UIView? {
    guard !viewModel.automaticBookmarks.isEmpty else { return nil }

    let header = UITableViewHeaderFooterView(reuseIdentifier: "Header")
    header.textLabel?.text =
      section == 0
      ? "bookmark_type_automatic_title".localized
      : "bookmark_type_user_title".localized

    guard section == 0 else { return header }

    let tap = UITapGestureRecognizer(target: self, action: #selector(didTapHeader(_:)))
    header.addGestureRecognizer(tap)

    return header
  }

  @objc private func didTapHeader(_ tap: UITapGestureRecognizer) {
    viewModel.isAutomaticSectionCollapsed.toggle()

    tableView.beginUpdates()
    let indexPaths = (0..<viewModel.automaticBookmarks.count)
      .map { IndexPath(row: $0, section: 0) }

    if viewModel.isAutomaticSectionCollapsed {
      tableView.deleteRows(at: indexPaths, with: .fade)
    } else {
      tableView.insertRows(at: indexPaths, with: .fade)
    }
    tableView.endUpdates()
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return section == 0
      ? viewModel.isAutomaticSectionCollapsed
        ? 0 : viewModel.automaticBookmarks.count
      : viewModel.userBookmarks.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    // swiftlint:disable force_cast
    let cell = tableView.dequeueReusableCell(withIdentifier: "BookmarkTableViewCell", for: indexPath) as! BookmarkTableViewCell

    let bookmark = indexPath.section == 0
    ? viewModel.automaticBookmarks[indexPath.row]
    : viewModel.userBookmarks[indexPath.row]

    cell.setup(with: bookmark)

    return cell
    // swiftlint:enable force_cast
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let bookmark = indexPath.section == 0
    ? viewModel.automaticBookmarks[indexPath.row]
    : viewModel.userBookmarks[indexPath.row]

    viewModel.handleBookmarkSelected(bookmark)

    done(nil)
  }

  override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard indexPath.section == 1 else { return nil }

    let bookmark = viewModel.userBookmarks[indexPath.row]

    let optionsAction = UIContextualAction(
      style: .normal,
      title: "bookmark_note_edit_title".localized
    ) { [weak self] _, _, completion in
      guard let self else { return }

      let alert = self.viewModel.getBookmarkNoteAlert(bookmark)

      self.present(alert, animated: true, completion: nil)
      completion(true)
    }

    let deleteAction = UIContextualAction(
      style: .destructive,
      title: "delete_button".localized
    ) { [weak self] _, _, completion in
      let alert = UIAlertController(title: nil,
                                    message: String(format: "delete_single_item_title".localized, TimeParser.formatTime(bookmark.time)),
                                    preferredStyle: .alert)

      alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

      alert.addAction(UIAlertAction(title: "delete_button".localized, style: .destructive, handler: { _ in
        self?.viewModel.deleteBookmark(bookmark)
        self?.reloadData()
      }))

      self?.present(alert, animated: true, completion: nil)
      completion(true)
    }

    return UISwipeActionsConfiguration(actions: [deleteAction, optionsAction])
  }
}

extension BookmarksViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.view.backgroundColor = theme.systemBackgroundColor
    self.tableView.backgroundColor = theme.systemBackgroundColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
    ? UIUserInterfaceStyle.dark
    : UIUserInterfaceStyle.light
  }
}
