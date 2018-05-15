//
//  NowPlayingViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 08.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import MarqueeLabelSwift

class NowPlayingViewController: PlayerContainerViewController, UIGestureRecognizerDelegate {
    @IBOutlet private weak var background: UIView!
    @IBOutlet private weak var artwork: UIImageView!
    @IBOutlet private weak var titleLabel: BPMarqueeLabel!
    @IBOutlet private weak var authorLabel: BPMarqueeLabel!
    @IBOutlet weak var playPauseButton: UIButton!

    private let playImage = UIImage(named: "nowPlayingPlay")
    private let pauseImage = UIImage(named: "nowPlayingPause")

    private var tap: UITapGestureRecognizer!
    private var pan: UIPanGestureRecognizer!

    var showPlayer: (() -> Void)?

    var book: Book? {
        didSet {
            self.artwork.image = self.book?.artwork
            self.authorLabel.text = self.book?.author
            self.titleLabel.text = self.book?.title
            self.titleLabel.textColor = self.book?.artworkColors.primary
            self.authorLabel.textColor = self.book?.artworkColors.secondary
        }
    }

    var isPlaying: Bool = false {
        didSet {
            self.playPauseButton.setImage(self.isPlaying ? self.pauseImage : self.playImage, for: UIControlState())
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.background.mask = UIImageView.squircleMask(frame: self.background.bounds)

        self.tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        self.tap.cancelsTouchesInView = true

        self.view.addGestureRecognizer(self.tap)

        self.pan = UIPanGestureRecognizer(target: self, action: #selector(panAction))
        self.pan.delegate = self
        self.pan.maximumNumberOfTouches = 1
        self.pan.cancelsTouchesInView = true

        self.view.addGestureRecognizer(self.pan)

        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
    }

    // Actions

    @objc private func onBookPlay() {
        self.isPlaying = true
    }

    @objc private func onBookPause() {
        self.isPlaying = false
    }

    @IBAction func playPause() {
        PlayerManager.shared.playPause()
    }

    // MARK: Gesture recognizers

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.pan {
            return limitPanAngle(self.pan, degreesOfFreedom: 60.0, comparator: .greaterThan)
        }

        return true
    }

    private func updatePresentedViewForTranslation(_ yTranslation: CGFloat) {
        let translation: CGFloat = rubberBandDistance(yTranslation, dimension: self.view.frame.height, constant: 0.8)
        let actionThreshold: CGFloat = self.view.frame.height * 0.4

        if fabs(translation) > actionThreshold {
            self.pan.isEnabled = false

            self.showPlayer?()

            if #available(iOS 10.0, *) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            self.resetPlayerPosition()

            return
        }

        self.view?.transform = CGAffineTransform(translationX: 0, y: min(translation, 0.0))
    }

    private func resetPlayerPosition() {
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 1.5,
            options: .preferredFramesPerSecond60,
            animations: {
                self.view?.transform = .identity
            }
        )
    }

    @objc func panAction(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(self.pan) else {
            return
        }

        switch gestureRecognizer.state {
            case .began:
                gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: self.view.superview)

            case .changed:
                let translation = gestureRecognizer.translation(in: self.view)

                self.updatePresentedViewForTranslation(translation.y)

            case .ended, .cancelled, .failed:
                self.resetPlayerPosition()

                self.pan.isEnabled = true

            default: break
        }
    }

    @objc func tapAction() {
        self.showPlayer?()
    }
}
