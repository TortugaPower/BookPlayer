//
//  PlayerControlsViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class PlayerControlsViewController: PlayerContainerViewController, UIGestureRecognizerDelegate {
    @IBOutlet private weak var artworkControl: ArtworkControl!
    @IBOutlet private weak var artworkHorizontal: NSLayoutConstraint!
    @IBOutlet private weak var progressSlider: ProgressSlider!
    @IBOutlet private weak var currentTimeLabel: UILabel!
    @IBOutlet private weak var maxTimeButton: UIButton!
    @IBOutlet private weak var progressButton: UIButton!

    var book: Book? {
        didSet {
            guard let book = self.book, !book.isFault else { return }

            self.artworkControl.artwork = book.artwork
            self.artworkControl.shadowOpacity = 0.1 + (1.0 - book.artworkColors.backgroundColor.brightness) * 0.3

            self.setProgress()
            applyTheme(self.themeProvider.currentTheme)
        }
    }

    private var currentTimeInContext: TimeInterval {
        guard let book = self.book, !book.isFault else {
            return 0.0
        }

        guard
            self.prefersChapterContext,
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
            self.prefersChapterContext,
            book.hasChapters,
            let duration = book.currentChapter?.duration else {
            let time = self.prefersRemainingTime
                ? self.currentTimeInContext - book.duration
                : book.duration
            return time
        }

        let time = self.prefersRemainingTime
            ? self.currentTimeInContext - duration
            : duration

        return time
    }

    private var durationTimeInContext: TimeInterval {
        guard let book = self.book, !book.isFault else {
            return 0.0
        }

        guard
            self.prefersChapterContext,
            book.hasChapters,
            let duration = book.currentChapter?.duration else {
            return book.duration
        }

        return duration
    }

    private var prefersChapterContext = UserDefaults.standard.bool(forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)

    private var prefersRemainingTime = UserDefaults.standard.bool(forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.artworkControl.isPlaying = PlayerManager.shared.isPlaying

        self.artworkControl.onPlayPause = { control in
            PlayerManager.shared.playPause()

            control.isPlaying = PlayerManager.shared.isPlaying
        }

        self.artworkControl.onRewind = { _ in
            PlayerManager.shared.rewind()
            self.showPlayPauseButton()
        }

        self.artworkControl.onForward = { _ in
            PlayerManager.shared.forward()
            self.showPlayPauseButton()
        }

        setUpTheming()

        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: .bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: .bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: .bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onPlayback), name: .bookPlaying, object: nil)
    }

    // MARK: - Notification Handlers

    @objc func onPlayback() {
        self.setProgress()
    }

    @objc private func onBookPlay() {
        self.artworkControl.isPlaying = true
    }

    @objc private func onBookPause() {
        self.artworkControl.isPlaying = false
    }

    // MARK: - Public API

    func showPlayPauseButton(_ animated: Bool = true) {
        self.artworkControl.showPlayPauseButton(animated)
    }

    // MARK: - Helpers

    private func setProgress() {
        guard let book = self.book, !book.isFault else {
            self.progressButton.setTitle("", for: .normal)

            return
        }

        if !self.progressSlider.isTracking {
            self.currentTimeLabel.text = self.formatTime(self.currentTimeInContext)
            self.currentTimeLabel.accessibilityLabel = String(describing: "Current Chapter Time: " + VoiceOverService.secondsToMinutes(self.currentTimeInContext))
            self.maxTimeButton.setTitle(self.formatTime(self.maxTimeInContext), for: .normal)
            let prefix = self.prefersRemainingTime
                ? "Remaining Chapter Time: "
                : "Chapter duration: "
            self.maxTimeButton.accessibilityLabel = String(describing: prefix + VoiceOverService.secondsToMinutes(maxTimeInContext))
        }

        guard
            self.prefersChapterContext,
            book.hasChapters,
            let chapters = book.chapters,
            let currentChapter = book.currentChapter else {
            if !self.progressSlider.isTracking {
                self.progressButton.setTitle("\(Int(round(book.progress * 100)))%", for: .normal)

                self.progressSlider.value = Float(book.progress)
                self.progressSlider.setNeedsDisplay()
                let prefix = self.prefersRemainingTime
                    ? "Remaining Book Time: "
                    : "Book duration: "
                self.maxTimeButton.accessibilityLabel = String(describing: prefix + VoiceOverService.secondsToMinutes(maxTimeInContext))
            }

            return
        }

        self.progressButton.isHidden = false
        self.progressButton.setTitle("Chapter \(currentChapter.index) of \(chapters.count)", for: .normal)

        if !self.progressSlider.isTracking {
            self.progressSlider.value = Float((book.currentTime - currentChapter.start) / currentChapter.duration)
            self.progressSlider.setNeedsDisplay()
        }
    }

    func transformArtworkView(_ value: CGFloat) {
        var transform = CATransform3DIdentity

        transform.m34 = 1.0 / 1000.0
        transform = CATransform3DRotate(transform, CGFloat.pi / 180 * 10, 0.5, (-value + 0.5) * 2, 0)

        self.artworkControl.layer.transform = transform
    }

    // MARK: - Storyboard Actions

    var chapterBeforeSliderValueChange: Chapter?

    @IBAction func toggleMaxTime(_ sender: UIButton) {
        self.prefersRemainingTime = !self.prefersRemainingTime
        UserDefaults.standard.set(self.prefersRemainingTime, forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)
        self.setProgress()
    }

    @IBAction func toggleProgressState(_ sender: UIButton) {
        self.prefersChapterContext = !self.prefersChapterContext
        UserDefaults.standard.set(self.prefersChapterContext, forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
        self.setProgress()
    }

    @IBAction func sliderDown(_ sender: UISlider, event: UIEvent) {
        self.artworkControl.isUserInteractionEnabled = false
        self.artworkControl.setAnchorPoint(anchorPoint: CGPoint(x: 0.5, y: 0.3))

        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveEaseOut, .beginFromCurrentState], animations: {
            self.transformArtworkView(CGFloat(self.progressSlider.value))
        })

        self.chapterBeforeSliderValueChange = self.book?.currentChapter
    }

    @IBAction func sliderUp(_ sender: UISlider, event: UIEvent) {
        self.artworkControl.isUserInteractionEnabled = true

        // Adjust the animation duration based on the distance of the thumb to the slider's center
        // This way the corners which look further away take a little longer to rest
        let duration = TimeInterval(abs(sender.value * 2 - 1) * 0.15 + 0.15)

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

        if self.prefersChapterContext, let currentChapter = book.currentChapter {
            newTime = currentChapter.start + TimeInterval(sender.value) * currentChapter.duration
        }

        PlayerManager.shared.jumpTo(newTime)
    }

    @IBAction func sliderValueChanged(_ sender: UISlider, event: UIEvent) {
        // This should be in ProgressSlider, but how to achieve that escapes my knowledge
        self.progressSlider.setNeedsDisplay()

        self.transformArtworkView(CGFloat(sender.value))

        guard let book = self.book, !book.isFault else {
            return
        }

        var newTimeToDisplay = TimeInterval(sender.value) * book.duration

        if self.prefersChapterContext, let currentChapter = self.chapterBeforeSliderValueChange {
            newTimeToDisplay = TimeInterval(sender.value) * currentChapter.duration
        }

        self.currentTimeLabel.text = self.formatTime(newTimeToDisplay)

        if !book.hasChapters || !self.prefersChapterContext {
            self.progressButton.setTitle("\(Int(round(sender.value * 100)))%", for: .normal)
        }

        if self.prefersRemainingTime {
            self.maxTimeButton.setTitle(self.formatTime(newTimeToDisplay - self.durationTimeInContext), for: .normal)
        }
    }
}

extension PlayerControlsViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.progressSlider.minimumTrackTintColor = theme.highlightColor
        self.progressSlider.maximumTrackTintColor = theme.lightHighlightColor

        self.artworkControl.iconColor = .white
        self.artworkControl.borderColor = theme.highlightColor

        self.currentTimeLabel.textColor = theme.primaryColor
        self.maxTimeButton.setTitleColor(theme.primaryColor, for: .normal)
        self.progressButton.setTitleColor(theme.primaryColor, for: .normal)
    }
}
