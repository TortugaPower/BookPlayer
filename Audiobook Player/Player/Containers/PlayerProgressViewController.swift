//
//  PlayerProgressViewController.swift
//  Audiobook Player
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

    var book: Book? {
        didSet {
            guard let book = self.book else {
                return
            }

            self.maxTimeLabel.text = self.formatTime(book.duration)
            self.currentTime = book.currentTime

            self.setPercentage()
        }
    }

    var currentTime: TimeInterval = 0.0 {
        didSet {
            self.currentTimeLabel.text = self.formatTime(self.currentTime)

            self.setPercentage()
        }
    }

    var duration: TimeInterval {
        guard let duration = self.book?.duration else {
            return 0.0
        }

        return duration
    }

    var colors: [UIColor]? {
        didSet {
            guard let color = self.colors?[2] else {
                return
            }

            self.progressSlider.minimumTrackTintColor = color
            self.progressSlider.maximumTrackTintColor = color.withAlphaComponent(0.3)

            self.currentTimeLabel.textColor = color
            self.maxTimeLabel.textColor = color
            self.percentageLabel.textColor = color
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.progressSlider.maximumValue = 100.0
        self.progressSlider.minimumValue = 0.0

        self.progressSlider.setThumbImage(#imageLiteral(resourceName: "thumbImageDefault"), for: .normal)
        self.progressSlider.setThumbImage(#imageLiteral(resourceName: "thumbImageSelected"), for: .selected)
        self.progressSlider.setThumbImage(#imageLiteral(resourceName: "thumbImageSelected"), for: .highlighted)

        NotificationCenter.default.addObserver(self, selector: #selector(self.onPlayback), name: Notification.Name.AudiobookPlayer.bookPlaying, object: nil)
    }

    private func setPercentage() {
        guard let book = self.book else {
            return
        }

        self.percentageLabel.text = book.percentCompletedRoundedString
        self.progressSlider.value = Float(book.percentCompleted)
    }

    @objc func onPlayback() {
        guard let time = self.book?.currentTime else {
            return
        }

        self.currentTime = time
    }

    @IBAction func sliderValueChanged(_ sender: UISlider) {
        self.currentTime = TimeInterval(sender.value / sender.maximumValue) * self.duration

        PlayerManager.sharedInstance.jumpTo(self.currentTime)
    }
}
