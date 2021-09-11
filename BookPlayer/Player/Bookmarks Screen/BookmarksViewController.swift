//
//  BookmarksViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class BookmarksViewController: UITableViewController, Storyboarded {
  var viewModel: BookmarksViewModel!

  var automaticBookmarks = [Bookmark]()
  var userBookmarks = [Bookmark]()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "bookmarks_title".localized

    self.tableView.tableFooterView = UIView()
    self.tableView.rowHeight = UITableView.automaticDimension
    self.tableView.estimatedRowHeight = 55.66

    self.reloadData()

    setUpTheming()
  }

  func reloadData() {
    self.userBookmarks = viewModel.getUserBookmarks()
    self.automaticBookmarks = viewModel.getAutomaticBookmarks()
    self.tableView.reloadData()
  }

  @IBAction func done(_ sender: UIBarButtonItem?) {
    self.viewModel.dismiss()
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    guard !self.automaticBookmarks.isEmpty else { return nil }

    return section == 0
      ? "bookmark_type_automatic_title".localized
      : "bookmark_type_user_title".localized
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return section == 0
      ? self.automaticBookmarks.count
      : self.userBookmarks.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    // swiftlint:disable force_cast
    let cell = tableView.dequeueReusableCell(withIdentifier: "BookmarkTableViewCell", for: indexPath) as! BookmarkTableViewCell

    let bookmark = indexPath.section == 0
      ? self.automaticBookmarks[indexPath.row]
      : self.userBookmarks[indexPath.row]

    cell.setup(with: bookmark)

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let bookmark = indexPath.section == 0
      ? self.automaticBookmarks[indexPath.row]
      : self.userBookmarks[indexPath.row]

    self.viewModel.handleBookmarkSelected(bookmark)

    self.done(nil)
  }

  override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
    guard indexPath.section == 1 else { return nil }

    let bookmark = self.userBookmarks[indexPath.row]

    let optionsAction = UIContextualAction(style: .normal, title: "bookmark_note_edit_title".localized) { _, _, completion in
      let alert = self.viewModel.getBookmarkNoteAlert(bookmark)

      self.present(alert, animated: true, completion: nil)
      completion(true)
    }

    let deleteAction = UIContextualAction(style: .destructive, title: "delete_button".localized) { _, _, completion in
      let alert = UIAlertController(title: nil,
                                    message: String(format: "delete_single_item_title".localized, TimeParser.formatTime(bookmark.time)),
                                    preferredStyle: .alert)

      alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

      alert.addAction(UIAlertAction(title: "delete_button".localized, style: .destructive, handler: { _ in
        self.viewModel.deleteBookmark(bookmark)
        self.reloadData()
      }))

      self.present(alert, animated: true, completion: nil)
      completion(true)
    }

    return UISwipeActionsConfiguration(actions: [deleteAction, optionsAction])
  }
}

extension BookmarksViewController: Themeable {
  func applyTheme(_ theme: Theme) {
    self.view.backgroundColor = theme.systemBackgroundColor
    self.tableView.backgroundColor = theme.systemBackgroundColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
  }
}
