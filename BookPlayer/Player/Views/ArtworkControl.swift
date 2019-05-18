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

    @IBOutlet private weak var artworkImage: BPArtworkView!
    @IBOutlet weak var artworkOverlay: UIView!
    @IBOutlet weak var artworkWidth: NSLayoutConstraint!
    @IBOutlet weak var artworkHeight: NSLayoutConstraint!

    private let playImage = UIImage(named: "playerIconPlay")
    private let pauseImage = UIImage(named: "playerIconPause")

    // Based on the design files for iPhone X where the regular artwork is 325dp and the paused state is 255dp in width
    private let artworkScalePaused: CGFloat = 255.0 / 325.0
    private let jumpIconAlpha: CGFloat = 1.0

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
        }
    }

    var shadowOpacity: CGFloat {
        get {
            return CGFloat(self.artworkImage.layer.shadowOpacity)
        }
        set {
            self.artworkImage.layer.shadowOpacity = Float(newValue)
        }
    }

    var isPlaying: Bool = false {
        didSet {
            self.playPauseButton.setImage(self.isPlaying ? self.pauseImage : self.playImage, for: UIControl.State())

            let scale: CGFloat = self.isPlaying ? 1.0 : 0.9

            UIView.animate(withDuration: 0.25,
                           delay: 0.0,
                           usingSpringWithDamping: 0.6,
                           initialSpringVelocity: 1.4,
                           options: .preferredFramesPerSecond60,
                           animations: {
                               self.transform = CGAffineTransform(scaleX: scale, y: scale)

                               self.playPauseButton.layoutIfNeeded()
            })

            self.playPauseButton.accessibilityLabel = self.isPlaying ? "Pause" : "Play"
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
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        self.layer.shadowOpacity = 0.15
        self.layer.shadowRadius = 12.0

        self.artworkOverlay.addLayerMask("playerIconShadow", backgroundColor: .playerControlsShadowColor)

        self.rewindIcon.alpha = self.jumpIconAlpha
        self.forwardIcon.alpha = self.jumpIconAlpha

        self.artworkImage.clipsToBounds = false
        self.artworkImage.contentMode = .scaleAspectFit
        self.artworkImage.layer.cornerRadius = 6.0
        self.artworkImage.layer.masksToBounds = true

        self.artworkOverlay.clipsToBounds = false
        self.artworkOverlay.contentMode = .scaleAspectFit
        self.artworkOverlay.layer.cornerRadius = 6.0
        self.artworkOverlay.layer.masksToBounds = true

        // Gestures
        let rewindTap = UILongPressGestureRecognizer(target: self, action: #selector(self.tapRewind))
        rewindTap.minimumPressDuration = 0
        rewindTap.delegate = self
        let forwardTap = UILongPressGestureRecognizer(target: self, action: #selector(self.tapForward))
        forwardTap.minimumPressDuration = 0
        forwardTap.delegate = self

        self.rewindIcon.addGestureRecognizer(rewindTap)
        self.forwardIcon.addGestureRecognizer(forwardTap)
    }

    // Voiceover
    private func setupAccessibilityLabels() {
        isAccessibilityElement = false
        self.playPauseButton.isAccessibilityElement = true
        self.playPauseButton.accessibilityLabel = self.isPlaying ? "Pause" : "Play"
        self.playPauseButton.accessibilityTraits = UIAccessibilityTraits(rawValue: super.accessibilityTraits.rawValue | UIAccessibilityTraits.button.rawValue)
        self.rewindIcon.accessibilityLabel = VoiceOverService.rewindText()
        self.forwardIcon.accessibilityLabel = VoiceOverService.fastForwardText()
        accessibilityElements = [
            playPauseButton as Any,
            rewindIcon as Any,
            forwardIcon as Any
        ]
    }

    // MARK: - Actions

    @IBAction private func playPauseButtonTouchUpInside() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        self.onPlayPause?(self)
    }

    // MARK: - Public API

    func showPlayPauseButton(_ animated: Bool = true) {
        self.playPauseButton.alpha = 1.0
        self.forwardIcon.alpha = 1.0
        self.rewindIcon.alpha = 1.0
        self.artworkOverlay.alpha = 1.0

        UIView.animate(withDuration: 0.3, delay: 2.2, options: .allowUserInteraction, animations: {
            self.playPauseButton.alpha = 0.05
            self.forwardIcon.alpha = 0.05
            self.rewindIcon.alpha = 0.05
            self.artworkOverlay.alpha = 0
        }, completion: nil)
    }

    // MARK: - Gesture recognizers

    @objc private func tapRewind(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .began
            || gestureRecognizer.state == .ended else {
            return
        }

        var transform = self.isPlaying
            ? CATransform3DIdentity
            : CATransform3DMakeScale(0.9, 0.9, 1)

        guard gestureRecognizer.state == .ended else {
            let touchPoint = gestureRecognizer.location(in: self.rewindIcon)
            let value = touchPoint.y / self.rewindIcon.frame.height

            transform.m34 = 1.0 / 1000.0
            transform = CATransform3DRotate(transform, 10 * CGFloat.pi / 180, (-value + 0.5) * -2, 0.5, 0)
            self.layer.transform = transform

            self.onRewind?(self)

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

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

        var transform = self.isPlaying
            ? CATransform3DIdentity
            : CATransform3DMakeScale(0.9, 0.9, 1)

        guard gestureRecognizer.state == .ended else {
            let touchPoint = gestureRecognizer.location(in: self.rewindIcon)
            let value = touchPoint.y / self.rewindIcon.frame.height

            transform.m34 = 1.0 / 1000.0
            transform = CATransform3DRotate(transform, 50, (-value + 0.5) * 2, 0.5, 0)
            self.layer.transform = transform

            self.onForward?(self)

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            return
        }

        UIView.animate(withDuration: 0.1, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
            self.layer.transform = transform
        })
    }
}
