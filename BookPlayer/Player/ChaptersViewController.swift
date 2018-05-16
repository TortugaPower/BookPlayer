//
// ChaptersViewController.swift
// BookPlayer
//
// Created by Gianni Carlo on 7/23/16.
// Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import MediaPlayer

class ChaptersViewController: UITableViewController {
    var chapters: [Chapter]!
    var currentChapter: Chapter!
    var didSelectChapter: ((_ selectedChapter: Chapter) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.tableFooterView = UIView()
        self.tableView.reloadData()
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

        cell.textLabel?.text = chapter.title
        cell.detailTextLabel?.text = self.formatTime(chapter.start)

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
