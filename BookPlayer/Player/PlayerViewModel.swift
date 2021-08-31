//
//  PlayerViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/8/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import UIKit
import StoreKit

struct ProgressObject {
  let currentTime: TimeInterval
  let progress: String?
  let maxTime: TimeInterval?
  let sliderValue: Float

  var formattedCurrentTime: String {
    return TimeParser.formatTime(self.currentTime)
  }

  var formattedMaxTime: String? {
    guard let maxTime = self.maxTime else { return nil }

    return TimeParser.formatTime(maxTime)
  }
}

class PlayerViewModel {
  private var chapterBeforeSliderValueChange: Chapter?
  private var prefersChapterContext = UserDefaults.standard.bool(forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
  private var prefersRemainingTime = UserDefaults.standard.bool(forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)
  @Published var currentBook: Book!

  func currentBookObserver() -> Published<Book?>.Publisher {
    return PlayerManager.shared.$currentBook
  }

  func isPlayingObserver() -> AnyPublisher<Bool, Never> {
    return PlayerManager.shared.isPlayingPublisher
  }

  func getBookChapters() -> [Chapter]? {
    return PlayerManager.shared.currentBook?.chapters?.array as? [Chapter]
  }

  func hasChapters() -> Bool {
    return PlayerManager.shared.currentBook?.hasChapters ?? false
  }

  func isBookFinished() -> Bool {
    return PlayerManager.shared.currentBook?.isFinished ?? false
  }

  func getBookCurrentTime() -> TimeInterval {
    return self.currentBook.currentTimeInContext(self.prefersChapterContext)
  }

  func getMaxTimeVoiceOverPrefix() -> String {
    return self.prefersRemainingTime
      ? "book_time_remaining_title".localized
      : "book_duration_title".localized
  }

  func handlePlayPauseAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    PlayerManager.shared.playPause()
  }

  func handleRewindAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    PlayerManager.shared.rewind()
  }

  func handleForwardAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    PlayerManager.shared.forward()
  }

  func processToggleMaxTime() -> ProgressObject {
    self.prefersRemainingTime = !self.prefersRemainingTime
    UserDefaults.standard.set(self.prefersRemainingTime, forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)

    return self.getCurrentProgressState()
  }

  func processToggleProgressState() -> ProgressObject {
    self.prefersChapterContext = !self.prefersChapterContext
    UserDefaults.standard.set(self.prefersChapterContext, forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)

    return self.getCurrentProgressState()
  }

  func getCurrentProgressState() -> ProgressObject {
    let currentTime = self.getBookCurrentTime()
    let maxTimeInContext = self.getBookMaxTime()
    let progress: String
    let sliderValue: Float

    if self.prefersChapterContext,
       currentBook.hasChapters,
       let chapters = currentBook.chapters,
       let currentChapter = currentBook.currentChapter {
      progress = String.localizedStringWithFormat("player_chapter_description".localized, currentChapter.index, chapters.count)
      sliderValue = Float((currentBook.currentTime - currentChapter.start) / currentChapter.duration)
    } else {
      progress = "\(Int(round(currentBook.progressPercentage * 100)))%"
      sliderValue = Float(currentBook.progressPercentage)
    }

    // Update local chapter
    self.chapterBeforeSliderValueChange = PlayerManager.shared.currentBook?.currentChapter

    return ProgressObject(
      currentTime: currentTime,
      progress: progress,
      maxTime: maxTimeInContext,
      sliderValue: sliderValue
    )
  }

  func handleSliderDownEvent() {
    self.chapterBeforeSliderValueChange = self.currentBook?.currentChapter
  }

  func handleSliderUpEvent(with value: Float) {
    let newTime = getBookTimeFromSlider(value: value)

    PlayerManager.shared.jumpTo(newTime)
  }

  func processSliderValueChangedEvent(with value: Float) -> ProgressObject {
    var newCurrentTime = getBookTimeFromSlider(value: value)

    if self.prefersChapterContext,
       let currentChapter = self.chapterBeforeSliderValueChange {
      newCurrentTime = TimeInterval(value) * currentChapter.duration
    }

    var newMaxTime: TimeInterval?

    if self.prefersRemainingTime {
      let durationTimeInContext = self.currentBook.durationTimeInContext(self.prefersChapterContext)

      newMaxTime = newCurrentTime - durationTimeInContext
    }

    var progress: String?

    if !self.currentBook.hasChapters || !self.prefersChapterContext {
      progress = "\(Int(round(value * 100)))%"
    }

    return ProgressObject(
      currentTime: newCurrentTime,
      progress: progress,
      maxTime: newMaxTime,
      sliderValue: value
    )
  }

  func getBookMaxTime() -> TimeInterval {
    return self.currentBook.maxTimeInContext(self.prefersChapterContext, self.prefersRemainingTime)
  }

  func getBookTimeFromSlider(value: Float) -> TimeInterval {
    var newTimeToDisplay = TimeInterval(value) * currentBook.duration

    if self.prefersChapterContext,
       let currentChapter = self.chapterBeforeSliderValueChange {
      newTimeToDisplay = currentChapter.start + TimeInterval(value) * currentChapter.duration
    }

    return newTimeToDisplay
  }

  func requestReview() {
    // don't do anything if flag isn't true
    guard UserDefaults.standard.bool(forKey: "ask_review") else { return }

    // request for review if app is active
    guard UIApplication.shared.applicationState == .active else { return }

    #if RELEASE
    SKStoreReviewController.requestReview()
    #endif

    UserDefaults.standard.set(false, forKey: "ask_review")
  }
}
