//
//  NowPlayingViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 08.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import MarqueeLabelSwift
import Themeable
import UIKit

class MiniPlayerViewController: PlayerContainerViewController, UIGestureRecognizerDelegate {
    @IBOutlet private weak var miniPlayerBlur: UIVisualEffectView!
    @IBOutlet private weak var miniPlayerContainer: UIView!
    @IBOutlet private weak var artwork: BPArtworkView!
    @IBOutlet private weak var titleLabel: BPMarqueeLabel!
    @IBOutlet private weak var authorLabel: BPMarqueeLabel!
    @IBOutlet private weak var playPauseButton: UIButton!
    @IBOutlet private weak var artworkWidth: NSLayoutConstraint!
    @IBOutlet private weak var artworkHeight: NSLayoutConstraint!

    private let playImage = UIImage(named: "nowPlayingPlay")
    private let pauseImage = UIImage(named: "nowPlayingPause")

    private var tap: UITapGestureRecognizer!

    var showPlayer: (() -> Void)?

    var book: Book? {
        didSet {
            self.view.setNeedsLayout()

            guard let book = self.book else { return }

            self.artwork.image = book.artwork
            self.authorLabel.text = book.author
            self.titleLabel.text = book.title

            let ratio = self.artwork.imageRatio

            self.artworkHeight.constant = ratio > 1 ? 50.0 / ratio : 50.0
            self.artworkWidth.constant = ratio < 1 ? 50.0 * ratio : 50.0
            setVoiceOverLabels()
            applyTheme(self.themeProvider.currentTheme)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpTheming()

        self.miniPlayerBlur.layer.cornerRadius = 13.0
        self.miniPlayerBlur.layer.masksToBounds = true

        self.tap = UITapGestureRecognizer(target: self, action: #selector(self.tapAction))
        self.tap.cancelsTouchesInView = true

        self.view.addGestureRecognizer(self.tap)

        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: .bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: .bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: .bookEnd, object: nil)
    }

    // MARK: Notification handlers

    @objc private func onBookPlay() {
        self.playPauseButton.setImage(self.pauseImage, for: UIControlState())
        self.playPauseButton.accessibilityHint = "Tap to Pause"
    }

    @objc private func onBookPause() {
        self.playPauseButton.setImage(self.playImage, for: UIControlState())
        self.playPauseButton.accessibilityHint = "Tap to Play"
    }

    // MARK: Actions

    @IBAction func playPause() {
        PlayerManager.shared.playPause()
    }

    // MARK: Gesture recognizers

    @objc func tapAction() {
        self.showPlayer?()
    }

    // MARK: - Voiceover

    private func setVoiceOverLabels() {
        let voiceOverTitle = titleLabel.text ?? "No Title"
        let voiceOverSubtitle = authorLabel.text ?? "No Author"
        titleLabel.accessibilityLabel = "Currently Playing \(voiceOverTitle) by \(voiceOverSubtitle)"
        accessibilityHint = "Miniplayer"
        playPauseButton.accessibilityHint = "Tap to Play"
    }
}

extension MiniPlayerViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        guard let book = self.book else { return }

        let appliedTheme: Theme = theme.isDark ? theme : book.artworkColors

        self.titleLabel.textColor = appliedTheme.primaryColor
        self.authorLabel.textColor = appliedTheme.detailColor
        self.playPauseButton.tintColor = appliedTheme.highlightColor

        self.miniPlayerContainer.backgroundColor = appliedTheme.backgroundColor

        self.miniPlayerBlur.effect = appliedTheme.isDark
            ? UIBlurEffect(style: .dark)
            : UIBlurEffect(style: .light)
    }
}
