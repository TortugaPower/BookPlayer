//
//  SleepTimerManager.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 30.03.18.
//  Copyright © 2018 Florian Pichler.
//

import UIKit
import Foundation

enum SleepTimerState {
    case ready
    case running
    case expired
}

typealias SleepTimerCompletion = () -> Void
typealias SleepTimerStart = () -> Void
typealias SleepTimerProgress = (Double) -> Void

final class SleepTimer {
    static let shared = SleepTimer()

    let durationFormatter = DateComponentsFormatter()

    var timer: Timer!
    var state: SleepTimerState = .ready
    var onStart: SleepTimerStart?
    var onProgress: SleepTimerProgress?
    var onCompletion: SleepTimerCompletion?

    let intervals: [Double] = [
        300.0,
        600.0,
        900.0,
        1800.0,
        2700.0,
        3600.0
    ]

    // MARK: Internals

    private init() {
        durationFormatter.unitsStyle = .positional
        durationFormatter.allowedUnits = [ .hour, .minute, .second ]
        durationFormatter.collapsesLargestUnit = true
        durationFormatter.zeroFormattingBehavior = .pad
    }

    private func sleep(in seconds: Double?) {
        UserDefaults.standard.set(seconds, forKey: "sleep_timer")

        guard seconds != nil else {
            self.reset()

            return
        }

        self.state = .running

        self.onStart?()
        self.onProgress?(seconds!)

        // create timer if needed
        if self.timer == nil || (self.timer != nil && !self.timer.isValid) {
            self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(update), userInfo: nil, repeats: true)

            RunLoop.main.add(self.timer, forMode: RunLoopMode.commonModes)
        }
    }

    private func reset() {
        self.state = .ready

        if self.timer != nil && self.timer.isValid {
            self.timer.invalidate()
        }

        UserDefaults.standard.set(nil, forKey: "sleep_timer")

        self.onCompletion?()
    }

    @objc private func update() {
        let currentTime = UserDefaults.standard.double(forKey: "sleep_timer")
        let newTime: Double? = currentTime - 1.0

        self.onProgress?(newTime!)

        if newTime! <= 0 {
            self.reset()

            return
        }

        UserDefaults.standard.set(newTime, forKey: "sleep_timer")
    }

    // MARK: Public methods

    func actionSheet(onStart: @escaping SleepTimerStart, onProgress: @escaping SleepTimerProgress, onCompletion: @escaping SleepTimerCompletion) -> UIAlertController {
        self.onStart = onStart
        self.onCompletion = onCompletion
        self.onProgress = onProgress

        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        alert.message = "Pause playback"

        alert.addAction(UIAlertAction(title: "Off", style: .default, handler: { _ in
            self.reset()
        }))

        let formatter = DateComponentsFormatter()

        formatter.unitsStyle = .full
        formatter.allowedUnits = [ .hour, .minute ]

        for interval in intervals {
            guard let formattedDuration = formatter.string(from: interval as TimeInterval) else {
                continue
            }

            alert.addAction(UIAlertAction(title: "In \(formattedDuration)", style: .default, handler: { _ in
                self.sleep(in: interval)
            }))
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        return alert
    }

    func format(duration: Double) -> String? {
        return self.durationFormatter.string(from: duration)
    }
}
