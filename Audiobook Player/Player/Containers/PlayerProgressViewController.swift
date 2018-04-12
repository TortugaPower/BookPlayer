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

    var currentTime: Double = 0.0 {
        didSet {
            currentTimeLabel.text = self.formatTime(Int(currentTime))
            self.setPercentage()
        }
    }

    var maxTime: Double = 0.0 {
        didSet {
            maxTimeLabel.text = self.formatTime(Int(maxTime))
            self.setPercentage()
        }
    }

    var percentage: Double = 0

    var tintColor: UIColor = .blue {
        didSet {
            self.progressSlider.tintColor = tintColor
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.progressSlider.tintColor = tintColor
        self.progressSlider.maximumValue = 100
        self.progressSlider.value = Float(percentage)

        NotificationCenter.default.addObserver(self, selector: #selector(self.onPlayback), name: Notification.Name.AudiobookPlayer.bookPlaying, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

        // Dispose of any resources that can be recreated.
    }

    private func setPercentage() {
        if currentTime == 0.0 || maxTime == 0.0 {
            percentage = 0.0
        } else {
            percentage = round(currentTime / maxTime * 100)
        }

        percentageLabel.text = "\(Int(percentage))%"
        progressSlider.value = Float(currentTime / maxTime * 100)
    }

    @objc func onPlayback(_ notification: Notification) {
        guard let userInfo = notification.userInfo, let time = userInfo["time"] as? Int else {
            return
        }

        currentTime = Double(time)
    }

    @IBAction func sliderValueChanged(_ sender: UISlider) {
        currentTime = TimeInterval(sender.value / sender.maximumValue) * maxTime

        guard let audioPlayer = PlayerManager.sharedInstance.audioPlayer else {
            return
        }

        audioPlayer.currentTime = currentTime
    }
}
