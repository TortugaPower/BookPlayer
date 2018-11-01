//
//  NowPlayingViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 08.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import MarqueeLabelSwift
import UIKit

class MiniPlayerViewController: PlayerContainerViewController, UIGestureRecognizerDelegate {
    @IBOutlet private var miniPlayerBlur: UIVisualEffectView!
    @IBOutlet private var miniPlayerContainer: UIView!
    @IBOutlet private var artwork: BPArtworkView!
    @IBOutlet private var titleLabel: BPMarqueeLabel!
    @IBOutlet private var authorLabel: BPMarqueeLabel!
    @IBOutlet private var playPauseButton: UIButton!
    @IBOutlet private var artworkWidth: NSLayoutConstraint!
    @IBOutlet private var artworkHeight: NSLayoutConstraint!

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
            self.miniPlayerContainer.backgroundColor = book.artworkColors.background.withAlphaComponent(book.artworkColors.displayOnDark ? 0.6 : 0.8)
            self.miniPlayerBlur.effect = book.artworkColors.displayOnDark ? UIBlurEffect(style: UIBlurEffectStyle.dark) : UIBlurEffect(style: UIBlurEffectStyle.light)

            let ratio = self.artwork.imageRatio

            self.artworkHeight.constant = ratio > 1 ? 50.0 / ratio : 50.0
            self.artworkWidth.constant = ratio < 1 ? 50.0 * ratio : 50.0
            setVoiceOverLabels()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        miniPlayerBlur.layer.cornerRadius = 13.0
        miniPlayerBlur.layer.masksToBounds = true

        tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        tap.cancelsTouchesInView = true

        view.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self, selector: #selector(onBookPlay), name: .bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onBookPause), name: .bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onBookPause), name: .bookEnd, object: nil)
    }

    // MARK: Notification handlers

    @objc private func onBookPlay() {
        playPauseButton.setImage(pauseImage, for: UIControlState())
        playPauseButton.accessibilityHint = "Tap to Pause"
    }

    @objc private func onBookPause() {
        playPauseButton.setImage(playImage, for: UIControlState())
        playPauseButton.accessibilityHint = "Tap to Play"
    }

    // MARK: Actions

    @IBAction func playPause() {
        PlayerManager.shared.playPause()
    }

    // MARK: Gesture recognizers

    @objc func tapAction() {
        showPlayer?()
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
