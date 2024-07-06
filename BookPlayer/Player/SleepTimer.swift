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

/// Available sleep timer states
enum SleepTimerState: Equatable {
  case off
  case countdown(TimeInterval)
  case endOfChapter
}

final class SleepTimer {
  static let shared = SleepTimer()

  /// Cancellable subscription of the active timer
  private var subscription: AnyCancellable?
  /// Threshold for volume fade event
  private let countDownThreshold: Int = 5

  /// Current time left on the timer
  @Published public var state: SleepTimerState = .off
  /// Last manually set sleep timer
  private var lastActiveState: SleepTimerState {
    didSet {
      let lastEnabledTimer: Double
      switch lastActiveState {
      case .off:
        lastEnabledTimer = -1
      case .countdown(let timeInterval):
        lastEnabledTimer = timeInterval
      case .endOfChapter:
        lastEnabledTimer = -2
      }
      UserDefaults.standard.set(
        lastEnabledTimer,
        forKey: Constants.UserDefaults.lastEnabledTimer
      )
    }
  }
  /// Default available options
  public let intervals: [TimeInterval] = [
    300.0,
    600.0,
    900.0,
    1800.0,
    3600.0
  ]

  /// Publisher when the countdown timer reaches the defined threshold
  public var countDownThresholdPublisher = PassthroughSubject<Bool, Never>()
  /// Publisher when the timer ends
  public var timerEndedPublisher = PassthroughSubject<SleepTimerState, Never>()

  // MARK: Internals

  private init() {
    let lastTimer = UserDefaults.standard.double(forKey: Constants.UserDefaults.lastEnabledTimer)
    switch lastTimer {
    case -2:
      lastActiveState = .endOfChapter
    case -1, 0:
      lastActiveState = .off
    default:
      lastActiveState = .countdown(lastTimer)
    }
  }

  /// Cancels any ongoing timer, and set the state to `.off`
  private func reset() {
    state = .off
    subscription?.cancel()
    NotificationCenter.default.removeObserver(self, name: .bookEnd, object: nil)
    NotificationCenter.default.removeObserver(self, name: .chapterChange, object: nil)
  }

  /// Siri intents integration
  private func donateTimerIntent(with option: TimerOption) {
    let intent = SleepTimerIntent()
    intent.option = option

    let interaction = INInteraction(intent: intent, response: nil)
    interaction.donate(completion: nil)
  }

  /// Periodic function used for the `countdown` case of ``SleepTimerState``
  @objc private func update() {
    guard case .countdown(let interval) = state else { return }

    let timeLeft = interval - 1

    if Int(timeLeft) == countDownThreshold {
      countDownThresholdPublisher.send(true)
    }

    if timeLeft <= 0 {
      self.end()
    } else {
      state = .countdown(timeLeft)
    }
  }

  /// Called by either the end of `.countdown` when the timer runs out or by `.endOfChapter` when a chapter or book has finished
  @objc private func end() {
    timerEndedPublisher.send(state)
    self.reset()
  }

  // MARK: Public methods
  
  public func setTimer(_ newState: SleepTimerState) {
    /// Always cancel any ongoing timer
    reset()
    state = newState

    switch newState {
    case .off:
      donateTimerIntent(with: .cancel)
    case .countdown(let interval):
      lastActiveState = newState
      if let option = TimeParser.getTimerOption(from: interval) {
        donateTimerIntent(with: option)
      }
      subscription = Timer.publish(every: 1, on: .main, in: .common)
        .autoconnect()
        .sink { [weak self] _ in
          self?.update()
        }
    case .endOfChapter:
      lastActiveState = newState
      donateTimerIntent(with: .endChapter)
      NotificationCenter.default.addObserver(self, selector: #selector(self.end), name: .chapterChange, object: nil)
      NotificationCenter.default.addObserver(self, selector: #selector(self.end), name: .bookEnd, object: nil)
    }
  }

  public func restartTimer() {
    setTimer(lastActiveState)
  }
}
