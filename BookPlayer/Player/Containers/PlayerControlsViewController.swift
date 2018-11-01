//
//  PlayerControlsViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlayerControlsViewController: PlayerContainerViewController, UIGestureRecognizerDelegate {
    @IBOutlet private var artworkControl: ArtworkControl!
    @IBOutlet private var artworkHorizontal: NSLayoutConstraint!
    @IBOutlet private var progressSlider: ProgressSlider!
    @IBOutlet private var currentTimeLabel: UILabel!
    @IBOutlet private var maxTimeButton: UIButton!
    @IBOutlet private var progressButton: UIButton!

    var book: Book? {
        didSet {
            guard let book = self.book, !book.isFault else {
                return
            }

            artworkControl.artwork = book.artwork
            artworkControl.shadowOpacity = 0.1 + (1.0 - book.artworkColors.background.brightness) * 0.3
            artworkControl.iconColor = book.artworkColors.tertiary
            artworkControl.borderColor = book.artworkColors.tertiary

            progressSlider.minimumTrackTintColor = book.artworkColors.tertiary
            progressSlider.maximumTrackTintColor = book.artworkColors.tertiary.withAlpha(newAlpha: 0.3)

            currentTimeLabel.textColor = book.artworkColors.tertiary
            maxTimeButton.setTitleColor(book.artworkColors.tertiary, for: .normal)
            progressButton.setTitleColor(book.artworkColors.primary, for: .normal)

            setProgress()
        }
    }

    private var currentTimeInContext: TimeInterval {
        guard let book = self.book, !book.isFault else {
            return 0.0
        }

        guard
            prefersChapterContext,
            book.hasChapters,
            let start = book.currentChapter?.start else {
            return book.currentTime
        }

        return book.currentTime - start
    }

    private var maxTimeInContext: TimeInterval {
        guard let book = self.book, !book.isFault else {
            return 0.0
        }

        guard
            prefersChapterContext,
            book.hasChapters,
            let duration = book.currentChapter?.duration else {
            let time = prefersRemainingTime
                ? currentTimeInContext - book.duration
                : book.duration
            return time
        }

        let time = prefersRemainingTime
            ? currentTimeInContext - duration
            : duration

        return time
    }

    private var durationTimeInContext: TimeInterval {
        guard let book = self.book, !book.isFault else {
            return 0.0
        }

        guard
            prefersChapterContext,
            book.hasChapters,
            let duration = book.currentChapter?.duration else {
            return book.duration
        }

        return duration
    }

    private var artworkJumpControlsUsed: Bool = false {
        didSet {
            UserDefaults.standard.set(artworkJumpControlsUsed, forKey: Constants.UserDefaults.artworkJumpControlsUsed.rawValue)
        }
    }

    private var prefersChapterContext = UserDefaults.standard.bool(forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)

    private var prefersRemainingTime = UserDefaults.standard.bool(forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        artworkJumpControlsUsed = UserDefaults.standard.bool(forKey: Constants.UserDefaults.artworkJumpControlsUsed.rawValue)

        artworkControl.isPlaying = PlayerManager.shared.isPlaying

        artworkControl.onPlayPause = { control in
            PlayerManager.shared.playPause()

            control.isPlaying = PlayerManager.shared.isPlaying
        }

        artworkControl.onRewind = { _ in
            PlayerManager.shared.rewind()

            if !self.artworkJumpControlsUsed {
                self.artworkJumpControlsUsed = true
            }
        }

        artworkControl.onForward = { _ in
            PlayerManager.shared.forward()

            if !self.artworkJumpControlsUsed {
                self.artworkJumpControlsUsed = true
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(onBookPlay), name: .bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onBookPause), name: .bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onBookPause), name: .bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onPlayback), name: .bookPlaying, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !artworkJumpControlsUsed {
            artworkControl.nudgeArtworkViewAnimated(0.5, duration: 0.3)
        }
    }

    // MARK: - Notification Handlers

    @objc func onPlayback() {
        setProgress()
    }

    @objc private func onBookPlay() {
        artworkControl.isPlaying = true
    }

    @objc private func onBookPause() {
        artworkControl.isPlaying = false
    }

    // MARK: - Public API

    func showPlayPauseButton(_ animated: Bool = true) {
        artworkControl.showPlayPauseButton(animated)
    }

    // MARK: - Helpers

    private func setProgress() {
        guard let book = self.book, !book.isFault else {
            progressButton.setTitle("", for: .normal)

            return
        }

        if !progressSlider.isTracking {
            currentTimeLabel.text = formatTime(currentTimeInContext)
            currentTimeLabel.accessibilityLabel = String(describing: "Current Chapter Time: " + VoiceOverService.secondsToMinutes(currentTimeInContext))
            maxTimeButton.setTitle(formatTime(maxTimeInContext), for: .normal)
            let prefix = prefersRemainingTime
                ? "Remaining Chapter Time: "
                : "Chapter duration: "
            maxTimeButton.accessibilityLabel = String(describing: prefix + VoiceOverService.secondsToMinutes(maxTimeInContext))
        }

        guard
            prefersChapterContext,
            book.hasChapters,
            let chapters = book.chapters,
            let currentChapter = book.currentChapter else {
            if !progressSlider.isTracking {
                progressButton.setTitle("\(Int(round(book.progress * 100)))%", for: .normal)

                progressSlider.value = Float(book.progress)
                progressSlider.setNeedsDisplay()
                let prefix = prefersRemainingTime
                    ? "Remaining Book Time: "
                    : "Book duration: "
                maxTimeButton.accessibilityLabel = String(describing: prefix + VoiceOverService.secondsToMinutes(maxTimeInContext))
            }

            return
        }

        progressButton.isHidden = false
        progressButton.setTitle("Chapter \(currentChapter.index) of \(chapters.count)", for: .normal)

        if !progressSlider.isTracking {
            progressSlider.value = Float((book.currentTime - currentChapter.start) / currentChapter.duration)
            progressSlider.setNeedsDisplay()
        }
    }

    func transformArtworkView(_ value: CGFloat) {
        var transform = CATransform3DIdentity

        transform.m34 = 1.0 / 1000.0
        transform = CATransform3DRotate(transform, CGFloat.pi / 180 * 10, 0.5, (-value + 0.5) * 2, 0)

        artworkControl.layer.transform = transform
    }

    // MARK: - Storyboard Actions

    var chapterBeforeSliderValueChange: Chapter?

    @IBAction func toggleMaxTime(_: UIButton) {
        prefersRemainingTime = !prefersRemainingTime
        UserDefaults.standard.set(prefersRemainingTime, forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)
        setProgress()
    }

    @IBAction func toggleProgressState(_: UIButton) {
        prefersChapterContext = !prefersChapterContext
        UserDefaults.standard.set(prefersChapterContext, forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
        setProgress()
    }

    @IBAction func sliderDown(_: UISlider, event _: UIEvent) {
        artworkControl.isUserInteractionEnabled = false
        artworkControl.setAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.3))

        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveEaseOut, .beginFromCurrentState], animations: {
            self.transformArtworkView(CGFloat(self.progressSlider.value))
        })

        chapterBeforeSliderValueChange = book?.currentChapter
    }

    @IBAction func sliderUp(_ sender: UISlider, event _: UIEvent) {
        artworkControl.isUserInteractionEnabled = true

        // Adjust the animation duration based on the distance of the thumb to the slider's center
        // This way the corners which look further away take a little longer to rest
        let duration = TimeInterval(fabs(sender.value * 2 - 1) * 0.15 + 0.15)

        UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
            self.artworkControl.layer.transform = CATransform3DIdentity
        }, completion: { _ in
            self.artworkControl.layer.zPosition = 0
            self.artworkControl.setAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.5))
        })

        guard let book = self.book, !book.isFault else {
            return
        }

        // Setting progress here instead of in `sliderValueChanged` to only register the value when the interaction
        // has ended, while still previwing the expected new time and progress in labels and display
        var newTime = TimeInterval(sender.value) * book.duration

        if prefersChapterContext, let currentChapter = book.currentChapter {
            newTime = currentChapter.start + TimeInterval(sender.value) * currentChapter.duration
        }

        PlayerManager.shared.jumpTo(newTime)
    }

    @IBAction func sliderValueChanged(_ sender: UISlider, event _: UIEvent) {
        // This should be in ProgressSlider, but how to achieve that escapes my knowledge
        progressSlider.setNeedsDisplay()

        transformArtworkView(CGFloat(sender.value))

        guard let book = self.book, !book.isFault else {
            return
        }

        var newTimeToDisplay = TimeInterval(sender.value) * book.duration

        if prefersChapterContext, let currentChapter = self.chapterBeforeSliderValueChange {
            newTimeToDisplay = TimeInterval(sender.value) * currentChapter.duration
        }

        currentTimeLabel.text = formatTime(newTimeToDisplay)

        if !book.hasChapters || !prefersChapterContext {
            progressButton.setTitle("\(Int(round(sender.value * 100)))%", for: .normal)
        }

        if prefersRemainingTime {
            maxTimeButton.setTitle(formatTime(newTimeToDisplay - durationTimeInContext), for: .normal)
        }
    }
}
