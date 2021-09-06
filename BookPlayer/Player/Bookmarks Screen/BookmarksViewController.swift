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
  private var viewModel = BookmarksViewModel()

  var automaticBookmarks = [Bookmark]()
  var userBookmarks = [Bookmark]()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "bookmarks_title".localized

    self.tableView.tableFooterView = UIView()
    self.tableView.rowHeight = UITableView.automaticDimension
    self.tableView.estimatedRowHeight = 55.66

    self.userBookmarks = viewModel.getUserBookmarks()
    self.automaticBookmarks = viewModel.getAutomaticBookmarks()

    setUpTheming()
  }

  @IBAction func done(_ sender: UIBarButtonItem?) {
    self.dismiss(animated: true, completion: nil)
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

    cell.timeLabel.text = TimeParser.formatTime(bookmark.time)
    cell.noteLabel.text = bookmark.note

    if let imageName = self.viewModel.getBookmarkImageName(for: bookmark.type) {
      cell.iconImageView.image = UIImage(systemName: imageName)
      cell.iconImageView.isHidden = false
    } else {
      cell.iconImageView.image = nil
      cell.iconImageView.isHidden = true
    }

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let bookmark = indexPath.section == 0
      ? self.automaticBookmarks[indexPath.row]
      : self.userBookmarks[indexPath.row]

    self.viewModel.handleBookmarkSelected(bookmark)

    self.done(nil)
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
