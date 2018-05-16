//
//  PlayerProgressViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlayerProgressViewController: PlayerContainerViewController {
    @IBOutlet private weak var progressSlider: UISlider!
    @IBOutlet private weak var currentTimeLabel: UILabel!
    @IBOutlet private weak var maxTimeLabel: UILabel!
    @IBOutlet private weak var percentageLabel: UILabel!
    @IBOutlet weak var sliderMin: UIImageView!
    @IBOutlet weak var sliderMax: UIImageView!
    @IBOutlet weak var minTrackWidth: NSLayoutConstraint!

    var book: Book? {
        didSet {
            self.setPercentage()

            self.currentTime = self.currentTimeInContext()
            self.maxTimeLabel.text = self.formatTime(self.maxTime)
        }
    }

    var maxTime: TimeInterval {
        guard let book = self.book else {
            return 0.0
        }

        return book.hasChapters ? book.currentChapter!.duration : book.duration
    }

    var currentTime: TimeInterval = 0.0 {
        didSet {
            self.currentTimeLabel.text = self.formatTime(self.currentTime)
            self.maxTimeLabel.text = self.formatTime(self.maxTime)

            self.setPercentage()

            guard let thumbWidth = self.progressSlider.currentThumbImage?.size.width else {
                return
            }

            let percentCompleted = CGFloat(self.progressSlider.value)
            let width = self.view.bounds.width

            self.minTrackWidth.constant = (width - thumbWidth) * percentCompleted + thumbWidth / 2
        }
    }

    var colors: ArtworkColors? {
        didSet {
            guard let colors = self.colors else {
                return
            }

            self.sliderMin.tintColor = colors.secondary
            self.sliderMax.tintColor = colors.secondary
            self.currentTimeLabel.textColor = colors.secondary
            self.maxTimeLabel.textColor = colors.secondary
            self.percentageLabel.textColor = colors.primary
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.progressSlider.maximumValue = 1.0
        self.progressSlider.minimumValue = 0.0

        self.progressSlider.setThumbImage(#imageLiteral(resourceName: "thumbImageDefault"), for: .normal)
        self.progressSlider.setThumbImage(#imageLiteral(resourceName: "thumbImageSelected"), for: .selected)
        self.progressSlider.setThumbImage(#imageLiteral(resourceName: "thumbImageSelected"), for: .highlighted)

        self.sliderMin.image = UIImage(named: "sliderMinimumTrack")?.resizableImage(
            withCapInsets: UIEdgeInsets(top: 0, left: 27.0, bottom: 0, right: 0),
            resizingMode: .stretch
        )

        self.sliderMax.image = UIImage(named: "sliderMaximumTrack")?.resizableImage(
            withCapInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 27.0),
            resizingMode: .stretch
        )

        NotificationCenter.default.addObserver(self, selector: #selector(self.onPlayback), name: Notification.Name.AudiobookPlayer.bookPlaying, object: nil)
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

    private func setPercentage() {
        guard let book = self.book else {
            return
        }

        self.percentageLabel.text = book.percentCompletedRoundedString

        guard let currentChapter = book.currentChapter else {
            self.progressSlider.value = Float(book.percentCompleted / 100)

            return
        }

        self.progressSlider.value = Float((book.currentTime - currentChapter.start) / currentChapter.duration)
    }

    @objc func onPlayback() {
        self.currentTime = self.currentTimeInContext()
    }

    @IBAction func sliderValueChanged(_ sender: UISlider, event: UIEvent) {
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
