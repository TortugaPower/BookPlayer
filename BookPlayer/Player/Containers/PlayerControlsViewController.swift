//
//  PlayerControlsViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlayerControlsViewController: PlayerContainerViewController, UIGestureRecognizerDelegate {
    @IBOutlet private weak var artworkControl: ArtworkControl!
    @IBOutlet private weak var artworkHorizontal: NSLayoutConstraint!
    @IBOutlet private weak var progressSlider: ProgressSlider!
    @IBOutlet private weak var currentTimeLabel: UILabel!
    @IBOutlet private weak var maxTimeLabel: UILabel!
    @IBOutlet private weak var progressLabel: UILabel!

    var book: Book? {
        didSet {
            guard let book = self.book else {
                return
            }

            self.artworkControl.artwork = book.artwork
            self.artworkControl.shadowOpacity = 0.1 + (1.0 - book.artworkColors.background.brightness) * 0.3
            self.artworkControl.iconColor = book.artworkColors.tertiary

            self.progressSlider.minimumTrackTintColor = book.artworkColors.tertiary
            self.progressSlider.maximumTrackTintColor = book.artworkColors.tertiary.withAlpha(newAlpha: 0.3)

            self.currentTimeLabel.textColor = book.artworkColors.tertiary
            self.maxTimeLabel.textColor = book.artworkColors.tertiary
            self.progressLabel.textColor = book.artworkColors.primary

            self.setProgress()
        }
    }

    private var currentTimeInContext: TimeInterval {
        guard let book = self.book else {
            return 0.0
        }

        guard book.hasChapters, let start = book.currentChapter?.start else {
            return book.currentTime
        }

        return book.currentTime - start
    }

    private var maxTimeInContext: TimeInterval {
        guard let book = self.book else {
            return 0.0
        }

        guard book.hasChapters, let duration = book.currentChapter?.duration else {
            return book.duration
        }

        return duration
    }

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
        }
        self.artworkControl.onForward = { _ in
            PlayerManager.shared.forward()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onPlayback), name: Notification.Name.AudiobookPlayer.bookPlaying, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
        guard let book = self.book else {
            self.progressLabel.text = ""

            return
        }

        self.maxTimeLabel.text = self.formatTime(self.maxTimeInContext)

        if !self.progressSlider.isTracking {
            self.currentTimeLabel.text = self.formatTime(self.currentTimeInContext)
        }

        guard book.hasChapters, let chapters = book.chapters, let currentChapter = book.currentChapter else {
            if !self.progressSlider.isTracking {
                self.progressLabel.text = "\(Int(round(book.progress * 100)))%"

                self.progressSlider.value = Float(book.progress)
                self.progressSlider.setNeedsDisplay()
            }

            return
        }

        self.progressLabel.isHidden = false
        self.progressLabel.text = "Chapter \(currentChapter.index) of \(chapters.count)"

        if !self.progressSlider.isTracking {
            self.progressSlider.value = Float((book.currentTime - currentChapter.start) / currentChapter.duration)
            self.progressSlider.setNeedsDisplay()
        }
    }

    // MARK: - Storyboard Actions

    var chapterBeforeSliderValueChange: Chapter?

    @IBAction func sliderDown(_ sender: UISlider, event: UIEvent) {
        self.chapterBeforeSliderValueChange = self.book?.currentChapter
    }

    @IBAction func sliderUp(_ sender: UISlider, event: UIEvent) {
        guard let book = self.book else {
            return
        }

        // Setting progress here instead of in `sliderValueChanged` to only register the value when the interaction
        // has ended, while still previwing the expected new time and progress in labels and display
        var newTime = TimeInterval(sender.value) * book.duration

        if let currentChapter = book.currentChapter {
            newTime = currentChapter.start + TimeInterval(sender.value) * currentChapter.duration
        }

        PlayerManager.shared.jumpTo(newTime)
    }

    @IBAction func sliderValueChanged(_ sender: UISlider, event: UIEvent) {
        // This should be in ProgressSlider, but how to achieve that escapes my knowledge
        self.progressSlider.setNeedsDisplay()

        guard let book = self.book else {
            return
        }

        var newTimeToDisplay = TimeInterval(sender.value) * book.duration

        if let currentChapter = self.chapterBeforeSliderValueChange {
            newTimeToDisplay = TimeInterval(sender.value) * currentChapter.duration
        }

        self.currentTimeLabel.text = self.formatTime(newTimeToDisplay)

        if !book.hasChapters {
            self.progressLabel.text = "\(Int(round(sender.value * 100)))%"
        }
    }
}
