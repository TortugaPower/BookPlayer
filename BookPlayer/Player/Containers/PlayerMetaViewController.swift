//
//  PlayerMetaViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import MarqueeLabelSwift
import UIKit

class PlayerMetaViewController: PlayerContainerViewController {
    @IBOutlet private var authorLabel: BPMarqueeLabel!
    @IBOutlet private var titleLabel: BPMarqueeLabel!
    @IBOutlet private var chapterLabel: BPMarqueeLabel!

    var book: Book? {
        didSet {
            authorLabel.text = book?.author
            titleLabel.text = book?.title

            titleLabel.textColor = book?.artworkColors.primary
            authorLabel.textColor = book?.artworkColors.secondary
            chapterLabel.textColor = book?.artworkColors.tertiary

            setChapterLabel()
            setAccessibilityLabel()
        }
    }

    var chapters: [Chapter]?

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(onPlayback), name: .bookPlaying, object: nil)
    }

    private func setChapterLabel() {
        guard let book = self.book, book.hasChapters, let currentChapter = book.currentChapter else {
            chapterLabel.text = ""
            chapterLabel.isEnabled = false

            return
        }

        chapterLabel.isEnabled = true
        chapterLabel.text = currentChapter.title != "" ? currentChapter.title : "Chapter \(currentChapter.index) of \(book.chapters?.count ?? 0)"
    }

    @objc func onPlayback(_: Notification) {
        setChapterLabel()
    }

    private func setAccessibilityLabel() {
        guard let book = book else {
            return accessibilityHint = "Player data unavailable"
        }
        authorLabel.accessibilityLabel = VoiceOverService().playerMetaText(book: book)
    }
}
