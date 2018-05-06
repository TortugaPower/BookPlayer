//
// ChaptersViewController.swift
// BookPlayer
//
// Created by Gianni Carlo on 7/23/16.
// Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import MediaPlayer

class ChaptersViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    var book: Book!
    var currentChapter: Chapter!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.currentChapter = self.book.currentChapter

        self.tableView.tableFooterView = UIView()
        self.tableView.reloadData()
    }

    @IBAction func done(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension ChaptersViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.book.chapters.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "ChapterViewCell", for: indexPath) as? ChapterViewCell {
            let chapter = self.book.chapters[indexPath.row]

            cell.titleLabel.text = chapter.title
            cell.durationLabel.text = formatTime(chapter.start)
            cell.titleLabel.highlightedTextColor = UIColor.black
            cell.durationLabel.highlightedTextColor = UIColor.black

            if self.book.currentChapter?.index == chapter.index {
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
            }

            return cell
        }

        return UITableViewCell()
    }
}

extension ChaptersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Don't set the chapter, set the new time which will set the chapter in didSet
        PlayerManager.sharedInstance.jumpTo(self.book.chapters[indexPath.row].start)

        self.dismiss(animated: true, completion: nil)
    }
}

class ChapterViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
}
