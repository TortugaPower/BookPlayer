//
//  PlayerControlsViewController.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import UIImageColors

class PlayerControlsViewController: PlayerContainerViewController, UIGestureRecognizerDelegate {
    @IBOutlet private weak var artworkView: UIView!
    @IBOutlet private weak var artwork: UIImageView!
    @IBOutlet private weak var playPauseButton: UIButton!
    @IBOutlet private weak var rewindButton: UIButton!
    @IBOutlet private weak var forwardButton: UIButton!

    private let playImage = UIImage(named: "playButton")
    private let pauseImage = UIImage(named: "pauseButton")
    private var pan: UIPanGestureRecognizer?

    var book: Book? {
        didSet {
            self.artwork.image = self.book?.artwork
        }
    }

    var isPlaying: Bool = false {
        didSet {
            self.playPauseButton.setImage(self.isPlaying ? self.pauseImage : self.playImage, for: UIControlState())
        }
    }

    var colors: UIImageColors? {
        didSet {
            guard let colors = self.colors else {
                return
            }

            // Control shadow strength via the inverse luminance of the background color.
            // Light backgrounds need a much more subtle shadow
            self.artwork.layer.shadowOpacity = 0.2 + Float(1.0 - colors.background.luminance) * 0.2
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.isPlaying = PlayerManager.sharedInstance.isPlaying

        self.artwork.layer.shadowColor = UIColor.black.cgColor
        self.artwork.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        self.artwork.layer.shadowOpacity = 0.2
        self.artwork.layer.shadowRadius = 12.0
        self.artwork.clipsToBounds = false

        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)

        self.setupGestures()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // skip time forward
    @IBAction private func forward(_ sender: Any) {
        PlayerManager.sharedInstance.forward()
    }

    // skip time backwards
    @IBAction private func rewind(_ sender: Any) {
        PlayerManager.sharedInstance.rewind()
    }

    // toggle play/pause of book
    @IBAction private func play(_ sender: Any) {
        PlayerManager.sharedInstance.playPause()

        self.isPlaying = PlayerManager.sharedInstance.isPlaying
    }

    @objc private func onBookPlay() {
        self.isPlaying = true
    }

    @objc private func onBookPause() {
        self.isPlaying = false
    }

    // MARK: Gesture recognizers

    private func setupGestures() {
        self.pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        self.pan!.delegate = self
        self.pan!.maximumNumberOfTouches = 1
        self.pan!.cancelsTouchesInView = false

        self.view.addGestureRecognizer(self.pan!)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // TODO: check x/y
        return true
    }

    private func updateArtworkViewForTranslation(_ translation: CGFloat) {
        let elasticThreshold: CGFloat = 120.0 * translation > 0 ? 1 : -1
        let dismissThreshold: CGFloat = 240.0 * translation > 0 ? 1 : -1
        let translationFactor: CGFloat = 0.5
        let absTranslation: CGFloat = abs(translation)

        let translationX: CGFloat = {
            if absTranslation >= elasticThreshold {
                let frictionLength = translation - elasticThreshold
                let frictionTranslation = 30 * atan(frictionLength/120) + frictionLength/10

                return frictionTranslation + (elasticThreshold * translationFactor)
            } else {
                return translation * translationFactor
            }
        }()

        self.artworkView?.transform = CGAffineTransform(translationX: translationX, y: 0)

        if translation >= dismissThreshold {
//            print("Do!")
        }
    }

    @objc private func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(self.pan) else {
            return
        }

        switch gestureRecognizer.state {
            case .began:
                gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: self.artworkView.superview)

            case .changed:
                let translation = gestureRecognizer.translation(in: self.artworkView)

                self.updateArtworkViewForTranslation(translation.x)

            case .ended:
                UIView.animate(
                    withDuration: 0.25,
                        animations: {
                            self.artworkView?.transform = .identity
                    }
                )

            default: break
        }
    }
}
