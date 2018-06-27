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
    @IBOutlet private weak var artwork: BPArtworkView!
    @IBOutlet private weak var titleLabel: BPMarqueeLabel!
    @IBOutlet private weak var authorLabel: BPMarqueeLabel!
    @IBOutlet private weak var playPauseButton: UIButton!
    @IBOutlet weak var artworkWidth: NSLayoutConstraint!
    @IBOutlet weak var artworkHeight: NSLayoutConstraint!

    private let playImage = UIImage(named: "nowPlayingPlay")
    private let pauseImage = UIImage(named: "nowPlayingPause")

    private var tap: UITapGestureRecognizer!

    var showPlayer: (() -> Void)?

    var book: Book? {
        didSet {
            self.view.setNeedsLayout()

            guard let book = self.book else {
                return
            }

            self.artwork.image = book.artwork
            self.authorLabel.text = book.author
            self.titleLabel.text = book.title
            self.titleLabel.textColor = book.artworkColors.primary
            self.authorLabel.textColor = book.artworkColors.secondary
            self.playPauseButton.tintColor = book.artworkColors.tertiary
            self.background.backgroundColor = book.artworkColors.background

            let ratio = self.artwork.imageRatio

            self.artworkHeight.constant = ratio > 1 ? 50.0 / ratio : 50.0
            self.artworkWidth.constant = ratio < 1 ? 50.0 * ratio : 50.0
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.background.layer.cornerRadius = 13.0

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
