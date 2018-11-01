//
// ChaptersViewController.swift
// BookPlayer
//
// Created by Gianni Carlo on 7/23/16.
// Copyright © 2016 Tortuga Power. All rights reserved.
//

import MediaPlayer
import UIKit

class ChaptersViewController: UITableViewController {
    var chapters: [Chapter]!

    var currentChapter: Chapter!
    var didSelectChapter: ((_ selectedChapter: Chapter) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()
        tableView.reloadData()
    }

    @IBAction func done(_: UIBarButtonItem?) {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return chapters.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChapterCell", for: indexPath)
        let chapter = chapters[indexPath.row]

        cell.textLabel?.text = chapter.title == "" ? "Chapter \(indexPath.row + 1)" : chapter.title
        cell.detailTextLabel?.text = "Start: \(formatTime(chapter.start)) - Duration: \(formatTime(chapter.duration))"
        cell.accessoryType = .none

        if currentChapter.index == chapter.index {
            cell.accessoryType = .checkmark
        }

        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectChapter?(chapters[indexPath.row])

        done(nil)
    }
}
