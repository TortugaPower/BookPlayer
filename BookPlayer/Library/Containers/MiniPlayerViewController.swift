//
//  NowPlayingViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 08.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import MarqueeLabelSwift

class MiniPlayerViewController: PlayerContainerViewController, UIGestureRecognizerDelegate {
    @IBOutlet private weak var background: UIView!
    @IBOutlet private weak var artwork: UIImageView!
    @IBOutlet private weak var titleLabel: BPMarqueeLabel!
    @IBOutlet private weak var authorLabel: BPMarqueeLabel!
    @IBOutlet weak var playPauseButton: UIButton!

    private let playImage = UIImage(named: "nowPlayingPlay")
    private let pauseImage = UIImage(named: "nowPlayingPause")

    private var tap: UITapGestureRecognizer!

    var showPlayer: (() -> Void)?

    var book: Book? {
        didSet {
            self.artwork.image = self.book?.artwork
            self.authorLabel.text = self.book?.author
            self.titleLabel.text = self.book?.title
            self.titleLabel.textColor = self.book?.artworkColors.primary
            self.authorLabel.textColor = self.book?.artworkColors.secondary
            self.playPauseButton.tintColor = self.book?.artworkColors.tertiary
            self.background.backgroundColor = self.book?.artworkColors.background
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.background.mask = UIImageView.squircleMask(frame: self.background.bounds)

        self.tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        self.tap.cancelsTouchesInView = true

        self.view.addGestureRecognizer(self.tap)

        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
    }

    // MARK: Notification handlers

    @objc private func onBookPlay() {
        self.playPauseButton.setImage(self.pauseImage, for: UIControlState())
    }

    @objc private func onBookPause() {
        self.playPauseButton.setImage(self.playImage, for: UIControlState())
    }

    // MARK: Actions

    @IBAction func playPause() {
        PlayerManager.shared.playPause()
    }

    // MARK: Gesture recognizers

    @objc func tapAction() {
        self.showPlayer?()
    }
}
