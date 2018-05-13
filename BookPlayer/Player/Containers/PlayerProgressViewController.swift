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

            guard let thumbWidth = self.progressSlider.currentThumbImage?.size.width else {
                return
            }

            let percentCompleted = CGFloat(self.currentTime / self.duration)
            let width = self.view.bounds.width

            self.minTrackWidth.constant = (width - thumbWidth) * percentCompleted + thumbWidth / 2

        }
    }

    var duration: TimeInterval {
        guard let duration = self.book?.duration else {
            return 0.0
        }

        return duration
    }

    var colors: ArtworkColors? {
        didSet {
            guard let secondaryColor = self.colors?.secondary else {
                return
            }

            self.sliderMin.tintColor = secondaryColor
            self.sliderMax.tintColor = secondaryColor

            self.currentTimeLabel.textColor = secondaryColor
            self.maxTimeLabel.textColor = secondaryColor
            self.percentageLabel.textColor = secondaryColor
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.progressSlider.maximumValue = 100.0
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

        PlayerManager.shared.jumpTo(self.currentTime)
    }
}
