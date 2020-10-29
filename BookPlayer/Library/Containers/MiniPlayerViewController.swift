//
//  NowPlayingViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 08.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import MarqueeLabel
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
        self.playPauseButton.setImage(self.pauseImage, for: UIControl.State())
        self.playPauseButton.accessibilityLabel = "pause_title".localized
    }

    @objc private func onBookPause() {
        self.playPauseButton.setImage(self.playImage, for: UIControl.State())
        self.playPauseButton.accessibilityLabel = "play_title".localized
    }

    // MARK: Actions

    @IBAction func playPause() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        PlayerManager.shared.playPause()
    }

    // MARK: Gesture recognizers

    @objc func tapAction() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        self.showPlayer?()
    }

    // MARK: - Voiceover

    private func setVoiceOverLabels() {
        let voiceOverTitle = self.titleLabel.text ?? "voiceover_no_title".localized
        let voiceOverSubtitle = self.authorLabel.text ?? "voiceover_no_author".localized
        self.titleLabel.accessibilityLabel = String(describing: String.localizedStringWithFormat("voiceover_currently_playing_title".localized, voiceOverTitle, voiceOverSubtitle))
        self.titleLabel.accessibilityHint = "voiceover_miniplayer_hint".localized
        self.playPauseButton.accessibilityLabel = "play_title".localized
        self.artwork.isAccessibilityElement = false
    }
}

extension MiniPlayerViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.titleLabel.textColor = theme.primaryColor
        self.authorLabel.textColor = theme.detailColor
        self.playPauseButton.tintColor = theme.highlightColor

        self.miniPlayerContainer.backgroundColor = theme.miniPlayerBackgroundColor

        self.miniPlayerBlur.effect = theme.useDarkVariant
            ? UIBlurEffect(style: .dark)
            : UIBlurEffect(style: .light)
    }
}
