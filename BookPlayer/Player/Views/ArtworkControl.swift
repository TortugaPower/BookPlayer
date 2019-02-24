//
//  ArtworkView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 22.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class ArtworkControl: UIView, UIGestureRecognizerDelegate {
    @IBOutlet var contentView: UIView!

    @IBOutlet private weak var rewindIcon: PlayerJumpIconRewind!
    @IBOutlet private weak var forwardIcon: PlayerJumpIconForward!
    @IBOutlet private weak var playPauseButton: UIButton!

    @IBOutlet private weak var artworkContainer: UIView!
    @IBOutlet private weak var artworkImage: BPArtworkView!
    @IBOutlet weak var artworkWidth: NSLayoutConstraint!
    @IBOutlet weak var artworkHeight: NSLayoutConstraint!
    @IBOutlet weak var playPauseButtonWidth: NSLayoutConstraint!
    @IBOutlet weak var playPauseButtonHeight: NSLayoutConstraint!

    private let playImage = UIImage(named: "playerIconPlay")
    private let pauseImage = UIImage(named: "playerIconPause")

    // Based on the design files for iPhone X where the regular artwork is 325dp and the paused state is 255dp in width
    private let artworkScalePaused: CGFloat = 255.0 / 325.0
    private let jumpIconAlpha: CGFloat = 1.0
    private let jumpIconOffset: CGFloat = 20.0

    var onPlayPause: ((ArtworkControl) -> Void)?
    var onRewind: ((ArtworkControl) -> Void)?
    var onForward: ((ArtworkControl) -> Void)?

    var iconColor: UIColor {
        get {
            return self.rewindIcon.tintColor
        }

        set {
            self.rewindIcon.tintColor = newValue
            self.forwardIcon.tintColor = newValue
        }
    }

    var borderColor: UIColor {
        get {
            return UIColor(cgColor: self.artworkImage.layer.borderColor!)
        }

        set {
            self.artworkImage.layer.borderColor = newValue.withAlphaComponent(0.2).cgColor
        }
    }

    var artwork: UIImage? {
        get {
            return self.artworkImage.image
        }

        set {
            self.artworkImage.image = newValue

            let ratio = self.artworkImage.imageRatio
            let base = min(self.artworkContainer.bounds.width, self.artworkContainer.bounds.height)

            self.artworkHeight.constant = ratio < 1 ? base * ratio : base
            self.artworkWidth.constant = ratio > 1 ? base / ratio : base
        }
    }

    var shadowOpacity: CGFloat {
        get {
            return CGFloat(self.artworkImage.layer.shadowOpacity)
        }
        set {
            let opacity = Float(newValue)
            self.artworkImage.layer.shadowOpacity = opacity
            self.playPauseButton.layer.shadowOpacity = 0.8
            self.playPauseButton.layer.shadowOffset = CGSize(width: 0, height: 0)
            self.forwardIcon.layer.shadowOpacity = 0.8
            self.forwardIcon.layer.shadowOffset = CGSize(width: 0, height: 0)
            self.rewindIcon.layer.shadowOpacity = 0.8
            self.rewindIcon.layer.shadowOffset = CGSize(width: 0, height: 0)
        }
    }

    var isPlaying: Bool = false {
        didSet {
            self.playPauseButton.setImage(self.isPlaying ? self.pauseImage : self.playImage, for: UIControlState())

            let scale: CGFloat = self.isPlaying ? 1.0 : 0.9

            self.playPauseButtonWidth.constant = self.artworkWidth.constant * scale - self.artworkWidth.constant
            self.playPauseButtonHeight.constant = self.artworkHeight.constant * scale - self.artworkHeight.constant

            if self.playPauseButtonHeight.constant < self.rewindIcon.frame.height {
                self.playPauseButtonHeight.constant = self.rewindIcon.frame.height
            }

            UIView.animate(withDuration: 0.25,
                           delay: 0.0,
                           usingSpringWithDamping: 0.6,
                           initialSpringVelocity: 1.4,
                           options: .preferredFramesPerSecond60,
                           animations: {
                               self.artworkImage.transform = CGAffineTransform(scaleX: scale, y: scale)

                               self.playPauseButton.layoutIfNeeded()

                               self.setTransformForJumpIcons()
            })

            self.showPlayPauseButton()
        }
    }

    // MARK: - Lifecycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.setup()
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        self.setupAccessibilityLabels()
    }

    private func setup() {
        self.backgroundColor = .clear

        // Load & setup xib
        Bundle.main.loadNibNamed("ArtworkControl", owner: self, options: nil)

        self.addSubview(self.contentView)

        self.contentView.frame = self.bounds
        self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // View & Subviews
        self.artworkContainer.layer.shadowColor = UIColor.black.cgColor
        self.artworkContainer.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        self.artworkContainer.layer.shadowOpacity = 0.15
        self.artworkContainer.layer.shadowRadius = 12.0

        self.rewindIcon.alpha = self.jumpIconAlpha
        self.forwardIcon.alpha = self.jumpIconAlpha

        self.artworkImage.clipsToBounds = false
        self.artworkImage.contentMode = .scaleAspectFit
        self.artworkImage.layer.cornerRadius = 6.0
        self.artworkImage.layer.masksToBounds = true

        let scale = self.isPlaying ? 1.0 : self.artworkScalePaused

        self.playPauseButtonWidth.constant = self.artworkWidth.constant * scale - self.artworkWidth.constant
        self.playPauseButtonHeight.constant = self.artworkHeight.constant * scale - self.artworkHeight.constant

        // Gestures
        let rewindTap = UILongPressGestureRecognizer(target: self, action: #selector(self.tapRewind))
        rewindTap.minimumPressDuration = 0
        rewindTap.delegate = self
        let forwardTap = UILongPressGestureRecognizer(target: self, action: #selector(self.tapForward))
        forwardTap.minimumPressDuration = 0
        forwardTap.delegate = self

        self.rewindIcon.addGestureRecognizer(rewindTap)
        self.forwardIcon.addGestureRecognizer(forwardTap)
//        self.addGestureRecognizer(rewindTap)
//        self.addGestureRecognizer(forwardTap)
    }

    func setTransformForJumpIcons() {
        if self.isPlaying {
            self.rewindIcon.transform = .identity
            self.forwardIcon.transform = .identity
        } else {
            self.rewindIcon.transform = CGAffineTransform(translationX: self.jumpIconOffset, y: 0.0)
            self.forwardIcon.transform = CGAffineTransform(translationX: -self.jumpIconOffset, y: 0.0)
        }
    }

    // Voiceover
    private func setupAccessibilityLabels() {
        isAccessibilityElement = false
        self.playPauseButton.isAccessibilityElement = true
        self.playPauseButton.accessibilityLabel = "Play Pause"
        self.playPauseButton.accessibilityTraits = super.accessibilityTraits | UIAccessibilityTraitButton
        self.rewindIcon.accessibilityLabel = VoiceOverService.rewindText()
        self.forwardIcon.accessibilityLabel = VoiceOverService.fastForwardText()
        accessibilityElements = [
            playPauseButton,
            rewindIcon,
            forwardIcon
        ]
    }

    // MARK: - Actions

    @IBAction private func playPauseButtonTouchUpInside() {
        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        self.onPlayPause?(self)
    }

    // MARK: - Public API

    func showPlayPauseButton(_ animated: Bool = true) {
        let fadeIn = {
            self.playPauseButton.alpha = 1.0
            self.forwardIcon.alpha = 1.0
            self.rewindIcon.alpha = 1.0
        }

        let fadeOut = {
            self.playPauseButton.alpha = 0.05
            self.forwardIcon.alpha = 0.05
            self.rewindIcon.alpha = 0.05
        }

        if animated || self.playPauseButton.alpha < 1.0 {
            UIView.animate(withDuration: 0.3, delay: 0, options: .allowUserInteraction, animations: fadeIn, completion: { (_: Bool) in
                UIView.animate(withDuration: 0.3, delay: 2.2, options: .allowUserInteraction, animations: fadeOut, completion: nil)
            })
        } else {
            UIView.animate(withDuration: 0.3, delay: 2.2, options: .allowUserInteraction, animations: fadeOut, completion: nil)
        }
    }

    // MARK: - Gesture recognizers

    @objc private func tapRewind(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .began
            || gestureRecognizer.state == .ended else {
            return
        }

        var transform = CATransform3DIdentity

        guard gestureRecognizer.state == .ended else {
            transform.m34 = 1.0 / 1000.0
            transform = CATransform3DRotate(transform, CGFloat.pi / 180 * 10, 0, 0.4, 0) //left
            self.layer.transform = transform
            self.onRewind?(self)
            return
        }

        UIView.animate(withDuration: 0.1, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
            self.layer.transform = transform
        })
    }

    @objc private func tapForward(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .began
            || gestureRecognizer.state == .ended else {
            return
        }

        var transform = CATransform3DIdentity

        guard gestureRecognizer.state == .ended else {
            transform.m34 = 1.0 / 1000.0
            transform = CATransform3DRotate(transform, 50, 0, 0.4, 0)
            self.layer.transform = transform
            self.onForward?(self)
            return
        }

        UIView.animate(withDuration: 0.1, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
            self.layer.transform = transform
        })
    }
}
