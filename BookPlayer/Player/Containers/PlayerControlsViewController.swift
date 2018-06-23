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

            self.maxTimeLabel.text = self.formatTime(self.maxTime)

            self.progressSlider.minimumTrackTintColor = book.artworkColors.tertiary
            self.progressSlider.maximumTrackTintColor = book.artworkColors.tertiary.withAlpha(newAlpha: 0.3)

            self.currentTimeLabel.textColor = book.artworkColors.tertiary
            self.maxTimeLabel.textColor = book.artworkColors.tertiary
            self.progressLabel.textColor = book.artworkColors.primary

            self.setProgress()
        }
    }

    private var maxTime: TimeInterval {
        guard let book = self.book else {
            return 0.0
        }

        guard book.hasChapters, let duration = book.currentChapter?.duration else {
            return book.duration
        }

        return duration
    }

    private var currentTime: TimeInterval = 0.0 {
        didSet {
            guard let book = self.book else {
                return
            }

            self.currentTimeLabel.text = self.formatTime(self.currentTime)
            self.maxTimeLabel.text = self.formatTime(self.maxTime)

            guard let currentChapter = book.currentChapter else {
                self.progressSlider.value = Float(book.progress)

                return
            }

            self.progressSlider.value = Float((book.currentTime - currentChapter.start) / currentChapter.duration)

            // This should be in ProgressSlider, but how to achieve that escapes my knowledge
            self.progressSlider.setNeedsDisplay()
        }
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

    // MARK: - Helpers

    func showPlayPauseButton(_ animated: Bool = true) {
        self.artworkControl.showPlayPauseButton(animated)
    }

    private func currentTimeInContext() -> TimeInterval {
        guard let book = self.book else {
            return 0.0
        }

        guard let currentChapter = book.currentChapter else {
            return book.currentTime
        }

        return book.currentTime - currentChapter.start
    }

    private func setProgress() {
        guard let book = self.book else {
            self.progressLabel.text = ""

            return
        }

        self.currentTime = self.currentTimeInContext()

        guard book.hasChapters, let chapters = book.chapters, let currentChapter = book.currentChapter else {
            self.progressLabel.text = book.percentCompletedRoundedString

            return
        }

        self.progressLabel.isHidden = false
        self.progressLabel.text = "Chapter \(currentChapter.index) of \(chapters.count)"
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

    // MARK: - Storyboard Actions

    @IBAction func sliderDown(_ sender: UISlider, event: UIEvent) {
        //
    }


    @IBAction func sliderUp(_ sender: UISlider, event: UIEvent) {
        //
    }

    @IBAction func sliderValueChanged(_ sender: UISlider, event: UIEvent) {
        self.progressSlider.setNeedsDisplay()

        guard let book = self.book else {
            return
        }

        let value = sender.value / sender.maximumValue


        let interval = TimeInterval(value)
        var currentTime = interval * book.duration

        if let currentChapter = book.currentChapter {
            currentTime = interval * currentChapter.duration + currentChapter.start
        }

        self.currentTime = self.currentTimeInContext()

        guard let touch = event.allTouches?.first else {
            return
        }

        // @TODO: Handle has chapter + playing + currentChapter already switched

        // Update while dragging up until but not including the very end of the chapter.
        // Move to the end of the chapter if the drag ends at the very end of the slider.
        // This prevents dragging the slider to the end of the chapter from skipping chapter by chapter while the drag continues to fire.
        if value < sender.maximumValue && touch.phase == .moved || (value == sender.maximumValue && touch.phase == .ended && PlayerManager.shared.currentTime <= self.currentTime) {
            PlayerManager.shared.jumpTo(currentTime)
        }
    }
}
