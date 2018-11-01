//
//  ArtworkView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 22.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

// swiftlint:disable type_body_length
class ArtworkControl: UIView, UIGestureRecognizerDelegate {
    @IBOutlet var contentView: UIView!

    @IBOutlet private var rewindIcon: PlayerJumpIconRewind!
    @IBOutlet private var forwardIcon: PlayerJumpIconForward!
    @IBOutlet private var playPauseButton: UIButton!

    @IBOutlet private var artworkContainer: UIView!
    @IBOutlet private var artworkImage: BPArtworkView!
    @IBOutlet var artworkWidth: NSLayoutConstraint!
    @IBOutlet var artworkHeight: NSLayoutConstraint!
    @IBOutlet var playPauseButtonWidth: NSLayoutConstraint!
    @IBOutlet var playPauseButtonHeight: NSLayoutConstraint!

    private let playImage = UIImage(named: "playerIconPlay")
    private let pauseImage = UIImage(named: "playerIconPause")

    private var pan: UIPanGestureRecognizer!
    private var tap: UITapGestureRecognizer!

    // Based on the design files for iPhone X where the regular artwork is 325dp and the paused state is 255dp in width
    private let artworkScalePaused: CGFloat = 255.0 / 325.0
    private let jumpIconAlpha: CGFloat = 0.15
    private let jumpIconOffset: CGFloat = 25.0
    private var triggeredPanAction: Bool = false

    var onPlayPause: ((ArtworkControl) -> Void)?
    var onRewind: ((ArtworkControl) -> Void)?
    var onForward: ((ArtworkControl) -> Void)?

    var iconColor: UIColor {
        get {
            return rewindIcon.tintColor
        }

        set {
            rewindIcon.tintColor = newValue
            forwardIcon.tintColor = newValue
        }
    }

    var borderColor: UIColor {
        get {
            return UIColor(cgColor: artworkImage.layer.borderColor!)
        }

        set {
            artworkImage.layer.borderColor = newValue.withAlphaComponent(0.2).cgColor
        }
    }

    var artwork: UIImage? {
        get {
            return artworkImage.image
        }

        set {
            artworkImage.image = newValue

            let ratio = artworkImage.imageRatio
            let base = min(artworkContainer.bounds.width, artworkContainer.bounds.height)

            artworkHeight.constant = ratio < 1 ? base * ratio : base
            artworkWidth.constant = ratio > 1 ? base / ratio : base
        }
    }

    var shadowOpacity: CGFloat {
        get {
            return CGFloat(artworkImage.layer.shadowOpacity)
        }
        set {
            artworkImage.layer.shadowOpacity = Float(newValue)
        }
    }

    var isPlaying: Bool = false {
        didSet {
            self.playPauseButton.setImage(self.isPlaying ? self.pauseImage : self.playImage, for: UIControlState())

            let scale = self.isPlaying ? 1.0 : self.artworkScalePaused

            self.playPauseButtonWidth.constant = self.artworkWidth.constant * scale - self.artworkWidth.constant
            self.playPauseButtonHeight.constant = self.artworkHeight.constant * scale - self.artworkHeight.constant

            UIView.animate(
                withDuration: 0.25,
                delay: 0.0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 1.4,
                options: .preferredFramesPerSecond60,
                animations: {
                    self.artworkImage.transform = CGAffineTransform(scaleX: scale, y: scale)

                    self.playPauseButton.layoutIfNeeded()

                    self.setTransformForJumpIcons()
                }
            )

            self.showPlayPauseButton()
        }
    }

    // MARK: - Lifecycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        setupAccessibilityLabels()
    }

    private func setup() {
        backgroundColor = .clear

        // Load & setup xib
        Bundle.main.loadNibNamed("ArtworkControl", owner: self, options: nil)

        addSubview(contentView)

        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // View & Subviews
        artworkContainer.layer.shadowColor = UIColor.black.cgColor
        artworkContainer.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        artworkContainer.layer.shadowOpacity = 0.15
        artworkContainer.layer.shadowRadius = 12.0

        rewindIcon.alpha = jumpIconAlpha
        forwardIcon.alpha = jumpIconAlpha

        artworkImage.clipsToBounds = false
        artworkImage.contentMode = .scaleAspectFit
        artworkImage.layer.cornerRadius = 6.0
        artworkImage.layer.masksToBounds = true

        let scale = isPlaying ? 1.0 : artworkScalePaused

        playPauseButtonWidth.constant = artworkWidth.constant * scale - artworkWidth.constant
        playPauseButtonHeight.constant = artworkHeight.constant * scale - artworkHeight.constant

        // Gestures
        pan = UIPanGestureRecognizer(target: self, action: #selector(panAction))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1

        addGestureRecognizer(pan!)

        tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        tap.delegate = self

        addGestureRecognizer(tap)
    }

    func setTransformForJumpIcons() {
        if isPlaying {
            rewindIcon.transform = CGAffineTransform(translationX: jumpIconOffset, y: 0.0)
            forwardIcon.transform = CGAffineTransform(translationX: -jumpIconOffset, y: 0.0)
        } else {
            rewindIcon.transform = .identity
            forwardIcon.transform = .identity
        }
    }

    // Voiceover
    private func setupAccessibilityLabels() {
        isAccessibilityElement = false
        playPauseButton.isAccessibilityElement = true
        playPauseButton.accessibilityLabel = "Play Pause"
        playPauseButton.accessibilityTraits = super.accessibilityTraits | UIAccessibilityTraitButton
        rewindIcon.accessibilityLabel = VoiceOverService.rewindText()
        forwardIcon.accessibilityLabel = VoiceOverService.fastForwardText()
        accessibilityElements = [
            playPauseButton,
            rewindIcon,
            forwardIcon,
        ]
    }

    // MARK: - Actions

    @IBAction private func playPauseButtonTouchUpInside() {
        onPlayPause?(self)
    }

    // MARK: - Public API

    func showPlayPauseButton(_ animated: Bool = true) {
        let fadeIn = {
            self.playPauseButton.alpha = 1.0
        }

        let fadeOut = {
            self.playPauseButton.alpha = 0.05
        }

        if animated || playPauseButton.alpha < 1.0 {
            UIView.animate(withDuration: 0.3, delay: 0, options: .allowUserInteraction, animations: fadeIn, completion: { (_: Bool) in
                UIView.animate(withDuration: 0.3, delay: 2.2, options: .allowUserInteraction, animations: fadeOut, completion: nil)
            })
        } else {
            UIView.animate(withDuration: 0.3, delay: 2.2, options: .allowUserInteraction, animations: fadeOut, completion: nil)
        }
    }

    // MARK: - Gesture recognizers

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == pan {
            return limitPanAngle(pan, degreesOfFreedom: 45.01, comparator: .lessThan)
        }

        return true
    }

    private func updateArtworkViewForTranslation(_ xTranslation: CGFloat) {
        let sign: CGFloat = xTranslation < 0 ? -1 : 1
        let width: CGFloat = rewindIcon.bounds.width
        let actionThreshold: CGFloat = width - 10.0
        let maximumPull: CGFloat = width + 5.0
        let translation: CGFloat = rubberBandDistance(fabs(xTranslation), dimension: width * 2 + 10.0, constant: 0.6)

        artworkContainer.transform = CGAffineTransform(translationX: translation * sign, y: 0)

        let factor: CGFloat = min(translation / actionThreshold, 1.0)
        let alpha: CGFloat = jumpIconAlpha + (1.0 - jumpIconAlpha) * factor
        let offset: CGFloat = isPlaying ? jumpIconOffset * (1 - factor) : 0.0

        if !triggeredPanAction {
            if xTranslation > 0 {
                rewindIcon.alpha = alpha
                rewindIcon.transform = CGAffineTransform(translationX: offset, y: 0.0)
            } else {
                forwardIcon.alpha = alpha
                forwardIcon.transform = CGAffineTransform(translationX: -offset, y: 0.0)
            }
        }

        if translation > actionThreshold && !triggeredPanAction {
            if #available(iOS 10.0, *) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

            UIView.animate(withDuration: 0.20, delay: 0.0, options: .curveEaseIn, animations: {
                self.rewindIcon.alpha = self.jumpIconAlpha
                self.forwardIcon.alpha = self.jumpIconAlpha
            })

            if sign < 0 {
                onForward?(self)
            } else {
                onRewind?(self)
            }

            triggeredPanAction = true
        }

        if translation > maximumPull {
            resetArtworkViewHorizontalConstraintAnimated()

            pan.isEnabled = false
            pan.isEnabled = true
        }
    }

    private func resetArtworkViewHorizontalConstraintAnimated() {
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 1.5,
            options: .preferredFramesPerSecond60,
            animations: {
                self.artworkContainer.transform = .identity
            }
        )

        UIView.animate(withDuration: 0.1, delay: 0.10, options: .curveEaseIn, animations: {
            self.rewindIcon.alpha = self.jumpIconAlpha
            self.forwardIcon.alpha = self.jumpIconAlpha

            self.setTransformForJumpIcons()
        })

        triggeredPanAction = false
    }

    func nudgeArtworkViewAnimated(_ direction: CGFloat = 1.0, duration: TimeInterval = 0.15) {
        UIView.animate(withDuration: duration, delay: 0.0, options: .curveEaseOut, animations: {
            self.updateArtworkViewForTranslation(self.jumpIconOffset * direction)
        }, completion: { _ in
            self.resetArtworkViewHorizontalConstraintAnimated()
        })
    }

    @objc private func panAction(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(pan) else {
            return
        }

        switch gestureRecognizer.state {
        case .began:
            gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: self)

        case .changed:
            let translation = gestureRecognizer.translation(in: self)

            updateArtworkViewForTranslation(translation.x)

        case .ended, .cancelled, .failed:
            resetArtworkViewHorizontalConstraintAnimated()

        case .possible: break
        }
    }

    @objc private func tapAction(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.isEqual(tap) else {
            return
        }

        if gestureRecognizer.state == .ended {
            let touch = gestureRecognizer.location(in: self)
            let inset = -jumpIconOffset

            if rewindIcon.frame.insetBy(dx: inset, dy: inset).contains(touch) {
                nudgeArtworkViewAnimated(0.5)
            } else if forwardIcon.frame.insetBy(dx: inset, dy: inset).contains(touch) {
                nudgeArtworkViewAnimated(-0.5)
            }
        }
    }
}
