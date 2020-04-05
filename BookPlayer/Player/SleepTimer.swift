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

    private let defaultMessage: String = "player_sleep_title".localized
    private let alert: UIAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    private var timeLeft: TimeInterval = 0.0
    private let intervals: [TimeInterval] = [
        300.0,
        600.0,
        900.0,
        1800.0,
        2700.0,
        3600.0
    ]

    public func isActive() -> Bool {
        return self.timer?.isValid ?? false
    }

    // MARK: Internals

    private init() {
        self.durationFormatter.unitsStyle = .positional
        self.durationFormatter.allowedUnits = [.minute, .second]
        self.durationFormatter.collapsesLargestUnit = true

        self.reset()

        let formatter = DateComponentsFormatter()

        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute]

        self.alert.addAction(UIAlertAction(title: "sleep_off_title".localized, style: .default, handler: { _ in
            self.cancel()
        }))

        for interval in self.intervals {
            let formattedDuration = formatter.string(from: interval as TimeInterval)!

            self.alert.addAction(UIAlertAction(title: String.localizedStringWithFormat("sleep_interval_title".localized, formattedDuration), style: .default, handler: { _ in
                self.sleep(in: interval)
            }))
        }

        self.alert.addAction(UIAlertAction(title: "sleep_chapter_option_title".localized, style: .default) { _ in
            self.cancel()
            self.alert.message = "sleep_alert_description".localized
            NotificationCenter.default.addObserver(self, selector: #selector(self.end), name: .chapterChange, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.end), name: .bookChange, object: nil)
        })

        self.alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
    }

    public func sleep(in seconds: Double) {
        NotificationCenter.default.post(name: .timerStart, object: nil)
        NotificationCenter.default.post(name: .timerProgress, object: nil, userInfo: ["timeLeft": seconds])

        self.reset()

        self.timeLeft = seconds
        self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)

        RunLoop.main.add(self.timer!, forMode: RunLoop.Mode.common)
    }

    private func reset() {
        self.alert.message = self.defaultMessage

        self.timer?.invalidate()
        NotificationCenter.default.removeObserver(self, name: .bookChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .chapterChange, object: nil)
    }

    public func cancel() {
        self.reset()

        NotificationCenter.default.post(name: .timerEnd, object: nil)
    }

    @objc private func update() {
        self.timeLeft -= 1.0

        NotificationCenter.default.post(name: .timerProgress, object: nil, userInfo: ["timeLeft": self.timeLeft])

        self.alert.message = String.localizedStringWithFormat("sleep_time_description".localized, self.durationFormatter.string(from: self.timeLeft)!)

        if self.timeLeft <= 0 {
            self.end()
        }
    }

    @objc private func end() {
        self.reset()

        PlayerManager.shared.pause()

        NotificationCenter.default.post(name: .timerEnd, object: nil)
    }

    // MARK: Public methods

    func actionSheet() -> UIAlertController {
        return self.alert
    }
}
