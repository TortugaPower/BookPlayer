//
//  SleepTimerManager.swift
//  BookPlayer
//
//  Created by Florian Pichler on 30.03.18.
//  Copyright © 2018 Florian Pichler.
//

import BookPlayerKit
import Combine
import Foundation
import IntentsUI
import UIKit

final class SleepTimer {
  static let shared = SleepTimer()

  let durationFormatter: DateComponentsFormatter = DateComponentsFormatter()

  private var subscription: AnyCancellable?
  private var alert: UIAlertController?

  @Published private var timeLeft: TimeInterval = 0.0

  private let defaultMessage: String = "player_sleep_title".localized
  private let intervals: [TimeInterval] = [
    300.0,
    600.0,
    900.0,
    1800.0,
    2700.0,
    3600.0
  ]

  public var timeLeftFormatted: AnyPublisher<String?, Never> {
    $timeLeft.map({ interval in
      // End of chapter
      if interval == -2 {
        return "active_title".localized
      }

      // Timer finished
      if interval == 0 {
        return nil
      }

      return self.durationFormatter.string(from: interval)
    }).eraseToAnyPublisher()
  }

  public func isActive() -> Bool {
    return self.subscription != nil || self.timeLeft == -2
  }

  public func isEndChapterActive() -> Bool {
    return self.timeLeft == -2
  }

  // MARK: Internals

  private init() {
    self.durationFormatter.unitsStyle = .positional
    self.durationFormatter.allowedUnits = [.minute, .second]
    self.durationFormatter.collapsesLargestUnit = true

    self.reset()
  }

  public func reset() {
    self.alert?.message = self.defaultMessage
    self.timeLeft = 0

    self.subscription?.cancel()
    NotificationCenter.default.removeObserver(self, name: .bookChange, object: nil)
    NotificationCenter.default.removeObserver(self, name: .chapterChange, object: nil)
  }

  private func donateTimerIntent(with option: TimerOption) {
    let intent = SleepTimerIntent()
    intent.option = option

    let interaction = INInteraction(intent: intent, response: nil)
    interaction.donate(completion: nil)
  }

  @objc private func update() {
    self.timeLeft -= 1.0

    self.alert?.message = String.localizedStringWithFormat("sleep_time_description".localized, self.durationFormatter.string(from: self.timeLeft)!)

    if self.timeLeft <= 0 {
      self.end()
    }
  }

  @objc private func end() {
    self.reset()

    PlayerManager.shared.pause(fade: true)

    self.subscription?.cancel()
  }

  private func startEndOfChapterOption() {
    self.reset()
    self.alert?.message = "sleep_alert_description".localized
    self.timeLeft = -2.0
    NotificationCenter.default.addObserver(self, selector: #selector(self.end), name: .chapterChange, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(self.end), name: .bookChange, object: nil)
    self.donateTimerIntent(with: .endChapter)
  }

  // MARK: Public methods

  func intentSheet(on vc: UIViewController) -> UIAlertController {
    let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

    let formatter = DateComponentsFormatter()

    formatter.unitsStyle = .full
    formatter.allowedUnits = [.hour, .minute]

    let intent = SleepTimerIntent()

    alert.addAction(UIAlertAction(title: "sleep_off_title".localized, style: .default, handler: { _ in
      intent.option = .cancel
      (vc as? IntentSelectionDelegate)?.didSelectIntent(intent)
    }))

    for interval in self.intervals {
      let formattedDuration = formatter.string(from: interval as TimeInterval)!

      alert.addAction(UIAlertAction(title: String.localizedStringWithFormat("sleep_interval_title".localized, formattedDuration), style: .default, handler: { _ in
        intent.option = TimeParser.getTimerOption(from: interval)
        (vc as? IntentSelectionDelegate)?.didSelectIntent(intent)
      }))
    }

    alert.addAction(UIAlertAction(title: "sleep_chapter_option_title".localized, style: .default) { _ in
      intent.option = .endChapter
      (vc as? IntentSelectionDelegate)?.didSelectIntent(intent)
    })

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

    return alert
  }

  func actionSheet() -> UIAlertController {
    if let alert = self.alert {
      return alert
    }

    let formatter = DateComponentsFormatter()

    formatter.unitsStyle = .full
    formatter.allowedUnits = [.hour, .minute]

    self.alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

    self.alert?.addAction(UIAlertAction(title: "sleep_off_title".localized, style: .default, handler: { _ in
      self.reset()
      self.donateTimerIntent(with: .cancel)
    }))

    for interval in self.intervals {
      let formattedDuration = formatter.string(from: interval as TimeInterval)!

      self.alert?.addAction(UIAlertAction(title: String.localizedStringWithFormat("sleep_interval_title".localized, formattedDuration), style: .default, handler: { _ in
        self.sleep(in: interval)
      }))
    }

    self.alert?.addAction(UIAlertAction(title: "sleep_chapter_option_title".localized, style: .default) { _ in
      self.startEndOfChapterOption()
    })

    self.alert?.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
    return self.alert!
  }

  public func sleep(in option: TimerOption) {
    let seconds = TimeParser.getSeconds(from: option)

    if seconds > 0 {
      self.sleep(in: seconds)
    } else if seconds == -1 {
      self.reset()
      self.donateTimerIntent(with: .cancel)
    } else if seconds == -2 {
      self.startEndOfChapterOption()
    }
  }

  public func sleep(in seconds: Double) {
    let option = TimeParser.getTimerOption(from: seconds)
    self.donateTimerIntent(with: option)

    self.reset()

    self.timeLeft = seconds
    self.subscription = Timer.publish(every: 1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.update()
      }
  }
}
