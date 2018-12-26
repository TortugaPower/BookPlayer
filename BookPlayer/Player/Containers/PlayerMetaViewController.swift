//
//  PlayerMetaViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import MarqueeLabelSwift
import Themeable
import UIKit

class PlayerMetaViewController: PlayerContainerViewController {
    @IBOutlet private weak var authorLabel: BPMarqueeLabel!
    @IBOutlet private weak var titleLabel: BPMarqueeLabel!
    @IBOutlet private weak var chapterLabel: BPMarqueeLabel!

    var book: Book? {
        didSet {
            self.authorLabel.text = self.book?.author
            self.titleLabel.text = self.book?.title

            self.setChapterLabel()
            self.setAccessibilityLabel()
            applyTheme(self.themeProvider.currentTheme)
        }
    }

    var chapters: [Chapter]?

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpTheming()

        NotificationCenter.default.addObserver(self, selector: #selector(self.onPlayback), name: .bookPlaying, object: nil)
    }

    private func setChapterLabel() {
        guard let book = self.book, book.hasChapters, let currentChapter = book.currentChapter else {
            self.chapterLabel.text = ""
            self.chapterLabel.isEnabled = false

            return
        }

        self.chapterLabel.isEnabled = true
        self.chapterLabel.text = currentChapter.title != "" ? currentChapter.title : "Chapter \(currentChapter.index) of \(book.chapters?.count ?? 0)"
    }

    @objc func onPlayback(_ notification: Notification) {
        self.setChapterLabel()
    }

    private func setAccessibilityLabel() {
        guard let book = book else {
            return accessibilityHint = "Player data unavailable"
        }
        self.authorLabel.accessibilityLabel = VoiceOverService().playerMetaText(book: book)
    }
}

extension PlayerMetaViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.titleLabel.textColor = theme.background.isDark ? theme.primary : self.book?.artworkColors.primary
        self.authorLabel.textColor = theme.background.isDark ? theme.secondary : self.book?.artworkColors.secondary
        self.chapterLabel.textColor = theme.background.isDark ? theme.secondary : self.book?.artworkColors.tertiary
    }
}
