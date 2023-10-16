//
// ChaptersViewController.swift
// BookPlayer
//
// Created by Gianni Carlo on 7/23/16.
// Copyright © 2016 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import MediaPlayer
import Themeable
import UIKit

final class ChaptersViewController: UITableViewController, Storyboarded {
  var viewModel: ChaptersViewModel!
  var chapters = [PlayableChapter]()
  var scrolledToCurrentChapter = false

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "chapters_title".localized

    self.tableView.tableFooterView = UIView()
    self.tableView.rowHeight = UITableView.automaticDimension
    self.tableView.estimatedRowHeight = 55.66

    self.chapters = viewModel.getItemChapters() ?? []

    setUpTheming()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    guard !self.scrolledToCurrentChapter,
          let currentChapter = self.viewModel.getCurrentChapter(),
          let index = self.chapters.firstIndex(of: currentChapter) else { return }

    self.scrolledToCurrentChapter = true
    let indexPath = IndexPath(row: index, section: 0)
    self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
  }

  @IBAction func done(_ sender: UIBarButtonItem?) {
    self.viewModel.dismiss()
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.chapters.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "ChapterCell", for: indexPath)
    let chapter = self.chapters[indexPath.row]

    cell.textLabel?.text = chapter.title == ""
    ? String.localizedStringWithFormat("chapter_number_title".localized, indexPath.row + 1)
    : chapter.title

    cell.detailTextLabel?.text = String.localizedStringWithFormat("chapters_item_description".localized, TimeParser.formatTime(chapter.start), TimeParser.formatTime(chapter.duration))
    cell.accessoryType = .none

    if let currentChapter = self.viewModel.getCurrentChapter(),
       currentChapter.index == chapter.index {
      cell.accessoryType = .checkmark
    }

    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.viewModel.handleChapterSelected(self.chapters[indexPath.row])

    self.done(nil)
  }
}

extension ChaptersViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.view.backgroundColor = theme.systemBackgroundColor
    self.tableView.backgroundColor = theme.systemBackgroundColor
    self.tableView.separatorColor = theme.separatorColor
  }
}
