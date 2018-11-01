//
//  SleepTimerManager.swift
//  BookPlayer
//
//  Created by Florian Pichler on 30.03.18.
//  Copyright © 2018 Florian Pichler.
//

import Foundation
import UIKit

typealias SleepTimerStart = () -> Void
typealias SleepTimerProgress = (Double) -> Void
typealias SleepTimerEnd = (_ cancelled: Bool) -> Void

final class SleepTimer {
    static let shared = SleepTimer()

    let durationFormatter: DateComponentsFormatter = DateComponentsFormatter()

    private var timer: Timer?
    private var onStart: SleepTimerStart?
    private var onProgress: SleepTimerProgress?
    private var onEnd: SleepTimerEnd?

    private let defaultMessage: String = "Pause playback"
    private let alert: UIAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    private var timeLeft: TimeInterval = 0.0
    private let intervals: [TimeInterval] = [
        300.0,
        600.0,
        900.0,
        1800.0,
        2700.0,
        3600.0,
    ]

    // MARK: Internals

    private init() {
        durationFormatter.unitsStyle = .positional
        durationFormatter.allowedUnits = [.minute, .second]
        durationFormatter.collapsesLargestUnit = true

        reset()

        let formatter = DateComponentsFormatter()

        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute]

        alert.addAction(UIAlertAction(title: "Off", style: .default, handler: { _ in
            self.cancel()
        }))

        for interval in intervals {
            let formattedDuration = formatter.string(from: interval as TimeInterval)!

            alert.addAction(UIAlertAction(title: "In \(formattedDuration)", style: .default, handler: { _ in
                self.sleep(in: interval)
            }))
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    }

    private func sleep(in seconds: Double) {
        onStart?()
        onProgress?(seconds)

        reset()

        timeLeft = seconds
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(update), userInfo: nil, repeats: true)

        RunLoop.main.add(timer!, forMode: RunLoopMode.commonModes)
    }

    private func reset() {
        alert.message = defaultMessage

        timer?.invalidate()
    }

    private func cancel() {
        reset()

        onEnd?(true)
    }

    @objc private func update() {
        timeLeft -= 1.0

        onProgress?(timeLeft)

        alert.message = "Sleeping in \(durationFormatter.string(from: timeLeft)!)"

        if timeLeft <= 0 {
            timer?.invalidate()

            onEnd?(false)
        }
    }

    // MARK: Public methods

    func actionSheet(onStart: @escaping SleepTimerStart, onProgress: @escaping SleepTimerProgress, onEnd: @escaping SleepTimerEnd) -> UIAlertController {
        self.onStart = onStart
        self.onEnd = onEnd
        self.onProgress = onProgress

        return alert
    }
}
