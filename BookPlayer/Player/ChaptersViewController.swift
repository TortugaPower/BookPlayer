//
// ChaptersViewController.swift
// BookPlayer
//
// Created by Gianni Carlo on 7/23/16.
// Copyright © 2016 Tortuga Power. All rights reserved.
//

import MediaPlayer
import Themeable
import UIKit

class ChaptersViewController: UITableViewController {
    var chapters: [Chapter]!

    var currentChapter: Chapter!
    var didSelectChapter: ((_ selectedChapter: Chapter) -> Void)?
    var scrolledToCurrentChapter = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.tableFooterView = UIView()
        setUpTheming()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard !self.scrolledToCurrentChapter, let index = self.chapters.firstIndex(of: self.currentChapter) else { return }

        self.scrolledToCurrentChapter = true
        let indexPath = IndexPath(row: index, section: 0)
        self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
    }

    @IBAction func done(_ sender: UIBarButtonItem?) {
        self.dismiss(animated: true, completion: nil)
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

        cell.textLabel?.text = chapter.title == "" ? "Chapter \(indexPath.row + 1)" : chapter.title
        cell.detailTextLabel?.text = "Start: \(self.formatTime(chapter.start)) - Duration: \(self.formatTime(chapter.duration))"
        cell.accessoryType = .none

        if self.currentChapter.index == chapter.index {
            cell.accessoryType = .checkmark
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.didSelectChapter?(self.chapters[indexPath.row])

        self.done(nil)
    }
}

extension ChaptersViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.view.backgroundColor = theme.backgroundColor
        self.tableView.backgroundColor = theme.backgroundColor
    }
}
