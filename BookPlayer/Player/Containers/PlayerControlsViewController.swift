//
//  PlayerControlsViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlayerControlsViewController: PlayerContainerViewController, UIGestureRecognizerDelegate {
    @IBOutlet private weak var artworkView: UIView!
    @IBOutlet private weak var artwork: UIImageView!
    @IBOutlet private weak var playPauseButton: UIButton!
    @IBOutlet private weak var rewindIcon: PlayerRewindIconView!
    @IBOutlet private weak var forwardIcon: PlayerForwardIconView!
    @IBOutlet private weak var artworkHeight: NSLayoutConstraint!
    @IBOutlet private weak var artworkHorizontal: NSLayoutConstraint!
    @IBOutlet private weak var forwardIconHorizontal: NSLayoutConstraint!
    @IBOutlet private weak var rewindIconHorizontal: NSLayoutConstraint!

    private let playImage = UIImage(named: "playerIconPlay")
    private let pauseImage = UIImage(named: "playerIconPause")
    private var pan: UIPanGestureRecognizer!
    private var originalHeight: CGFloat!
    private let jumpIconAlpha: CGFloat = 0.15
    private var triggeredPanAction: Bool = false

    // Based on the design files for iPhone X where the regular artwork is 325dp and the paused state is 255dp in width
    private let artworkScalePaused: CGFloat = 255.0 / 325.0
    private let jumpIconOffsetPlaying: CGFloat = 25.0
    private let jumpIconOffsetPaused: CGFloat = 15.0

    private var isPlaying: Bool = false {
        didSet {
            self.playPauseButton.setImage(self.isPlaying ? self.pauseImage : self.playImage, for: UIControlState())

            self.view.layoutIfNeeded()
            self.artworkHeight.constant = self.isPlaying ? self.originalHeight : self.originalHeight * self.artworkScalePaused
            self.forwardIconHorizontal.constant = self.isPlaying ? self.jumpIconOffsetPlaying : self.jumpIconOffsetPaused
            self.rewindIconHorizontal.constant = self.isPlaying ? self.jumpIconOffsetPlaying : self.jumpIconOffsetPaused
            self.view.setNeedsLayout()

            UIView.animate(
                withDuration: 0.25,
                delay: 0.0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 1.4,
                options: .preferredFramesPerSecond60,
                animations: {
                    self.artwork.mask?.frame = self.artwork.bounds
                    self.view.layoutIfNeeded()
                }
            )

            self.showPlayPauseButton()
        }
    }

    var book: Book? {
        didSet {
            self.artwork.image = self.book?.artwork
        }
    }

    var colors: ArtworkColors? {
        didSet {
            guard let colors = self.colors else {
                return
            }

            self.rewindIcon.tintColor = colors.tertiary
            self.forwardIcon.tintColor = colors.tertiary

            self.artwork.layer.shadowOpacity = 0.1 + Float(1.0 - colors.background.luminance) * 0.3
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.originalHeight = self.artworkHeight.constant
        self.isPlaying = PlayerManager.shared.isPlaying

        self.artwork.layer.shadowColor = UIColor.black.cgColor
        self.artwork.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        self.artwork.layer.shadowOpacity = 0.2
        self.artwork.layer.shadowRadius = 12.0
        self.artwork.clipsToBounds = false

        self.rewindIcon.alpha = self.jumpIconAlpha
        self.forwardIcon.alpha = self.jumpIconAlpha

        self.updateSkipButtons()

        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)

        self.setupGestures()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func updateSkipButtons() {
        self.rewindIcon.title = "−\(Int(PlayerManager.sharedInstance.rewindInterval.rounded()))s"
        self.forwardIcon.title = "+\(Int(PlayerManager.sharedInstance.forwardInterval.rounded()))s"
    }

    func showPlayPauseButton(_ animated: Bool = true) {
        let fadeIn = {
            self.playPauseButton.alpha = 1.0
        }

        let fadeOut = {
            self.playPauseButton.alpha = 0.05
        }

        if animated || self.playPauseButton.alpha < 1.0 {
            UIView.animate(withDuration: 0.3, delay: 0, options: .allowUserInteraction, animations: fadeIn, completion: { (_: Bool) in
                UIView.animate(withDuration: 0.3, delay: 2.2, options: .allowUserInteraction, animations: fadeOut, completion: nil)
            })
        } else {
            UIView.animate(withDuration: 0.3, delay: 2.2, options: .allowUserInteraction, animations: fadeOut, completion: nil)
        }
    }

    // toggle play/pause of book
    @IBAction private func play(_ sender: Any) {
        PlayerManager.shared.playPause()

        self.isPlaying = PlayerManager.shared.isPlaying
    }

    @objc private func onBookPlay() {
        self.isPlaying = true
    }

    @objc private func onBookPause() {
        self.isPlaying = false
    }

    // MARK: Gesture recognizers

    private func setupGestures() {
        self.pan = UIPanGestureRecognizer(target: self, action: #selector(panAction))
        self.pan.delegate = self
        self.pan.maximumNumberOfTouches = 1
        self.pan.cancelsTouchesInView = true

        self.view.addGestureRecognizer(self.pan!)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.pan {
            return limitPanAngle(self.pan, degreesOfFreedom: 45.01, comparator: .lessThan)
        }

        return true
    }

    private func updateArtworkViewForTranslation(_ xTranslation: CGFloat) {
        let sign: CGFloat = xTranslation < 0 ? -1 : 1
        let width: CGFloat = self.rewindIcon.bounds.width
        let actionThreshold: CGFloat = width - 10.0
        let maximumPull: CGFloat = width + 5.0
        let translation: CGFloat = rubberBandDistance(fabs(xTranslation), dimension: width * 2 + 10.0, constant: 0.6)

        self.artworkHorizontal.constant = translation * sign

        let alpha: CGFloat = self.jumpIconAlpha + min(translation / actionThreshold, 1.0) * (1.0 - self.jumpIconAlpha)

        if !self.triggeredPanAction {
            if xTranslation > 0 {
                self.rewindIcon.alpha = alpha
            } else {
                self.forwardIcon.alpha = alpha
            }
        }

        if translation > actionThreshold && !self.triggeredPanAction {
            if #available(iOS 10.0, *) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            UIView.animate(withDuration: 0.2) {
                self.rewindIcon.alpha = self.jumpIconAlpha
                self.forwardIcon.alpha = self.jumpIconAlpha
            }

            if sign < 0 {
                PlayerManager.shared.forward()
            } else {
                PlayerManager.shared.rewind()
            }

            self.triggeredPanAction = true
        }

        if translation > maximumPull {
            self.resetArtworkViewHorizontalConstraintAnimated()

            self.pan.isEnabled = false
            self.pan.isEnabled = true
        }
    }

    func resetArtworkViewHorizontalConstraintAnimated() {
        self.artworkHorizontal.constant = 0.0

        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 1.5,
            options: .preferredFramesPerSecond60,
            animations: {
                self.view.layoutIfNeeded()
            }
        )

        UIView.animate(withDuration: 0.20, delay: 0.10, options: .curveEaseOut, animations: {
            self.rewindIcon.alpha = self.jumpIconAlpha
            self.forwardIcon.alpha = self.jumpIconAlpha
        }, completion: nil)

        self.triggeredPanAction = false
    }

    @objc private func panAction(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(self.pan) else {
            return
        }

        switch gestureRecognizer.state {
            case .began:
                gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: self.artworkView.superview)

            case .changed:
                let translation = gestureRecognizer.translation(in: self.artworkView)

                self.updateArtworkViewForTranslation(translation.x)

            case .ended, .cancelled, .failed:
                self.resetArtworkViewHorizontalConstraintAnimated()

            case .possible: break
        }
    }
}
