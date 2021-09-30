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

class PlayerViewModel {
  private let playerManager: PlayerManager
  private let dataManager: DataManager
  weak var coordinator: PlayerCoordinator!
  private var chapterBeforeSliderValueChange: Chapter?
  private var prefersChapterContext = UserDefaults.standard.bool(forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
  private var prefersRemainingTime = UserDefaults.standard.bool(forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)

  init(playerManager: PlayerManager,
       dataManager: DataManager) {
    self.playerManager = playerManager
    self.dataManager = dataManager
  }

  func currentBookObserver() -> Published<Book?>.Publisher {
    return self.playerManager.$currentBook
  }

  func isPlayingObserver() -> AnyPublisher<Bool, Never> {
    return self.playerManager.isPlayingPublisher
  }

  func hasLoadedBook() -> Bool {
    return self.playerManager.hasLoadedBook
  }

  func hasChapters() -> AnyPublisher<Bool, Never> {
    return self.playerManager.hasChapters.eraseToAnyPublisher()
  }

  func hasPreviousChapter() -> Bool {
    return self.playerManager.currentBook?.previousChapter() != nil
  }

  func hasNextChapter() -> Bool {
    return self.playerManager.currentBook?.nextChapter() != nil
  }

  func handlePreviousChapterAction() {
    guard let previousChapter = self.playerManager.currentBook?.previousChapter() else { return }

    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    self.playerManager.jumpTo(previousChapter.start + 0.5)
  }

  func handleNextChapterAction() {
    guard let nextChapter = self.playerManager.currentBook?.nextChapter() else { return }

    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    self.playerManager.jumpTo(nextChapter.start + 0.5)
  }

  func isBookFinished() -> Bool {
    return self.playerManager.currentBook?.isFinished ?? false
  }

  func getBookCurrentTime() -> TimeInterval {
    return self.playerManager.currentBook?.currentTimeInContext(self.prefersChapterContext) ?? 0
  }

  func getMaxTimeVoiceOverPrefix() -> String {
    return self.prefersRemainingTime
      ? "book_time_remaining_title".localized
      : "book_duration_title".localized
  }

  func handlePlayPauseAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    self.playerManager.playPause()
  }

  func handleRewindAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    self.playerManager.rewind()
  }

  func handleForwardAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    self.playerManager.forward()
  }

  func handleJumpToStart() {
    self.playerManager.pause()
    self.playerManager.jumpTo(0.0)
  }

  func handleMarkCompletion() {
    self.playerManager.pause()
    self.playerManager.markAsCompleted(!self.isBookFinished())
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
       let currentBook = self.playerManager.currentBook,
       currentBook.hasChapters,
       let chapters = currentBook.chapters,
       let currentChapter = currentBook.currentChapter {
      progress = String.localizedStringWithFormat("player_chapter_description".localized, currentChapter.index, chapters.count)
      sliderValue = Float((currentBook.currentTime - currentChapter.start) / currentChapter.duration)
    } else {
      progress = "\(Int(round((self.playerManager.currentBook?.progressPercentage ?? 0) * 100)))%"
      sliderValue = Float(self.playerManager.currentBook?.progressPercentage ?? 0)
    }

    // Update local chapter
    self.chapterBeforeSliderValueChange = self.playerManager.currentBook?.currentChapter

    return ProgressObject(
      currentTime: currentTime,
      progress: progress,
      maxTime: maxTimeInContext,
      sliderValue: sliderValue
    )
  }

  func handleSliderDownEvent() {
    self.chapterBeforeSliderValueChange = self.playerManager.currentBook?.currentChapter
  }

  func handleSliderUpEvent(with value: Float) {
    let newTime = getBookTimeFromSlider(value: value)

    self.playerManager.jumpTo(newTime)
  }

  func processSliderValueChangedEvent(with value: Float) -> ProgressObject {
    var newCurrentTime = getBookTimeFromSlider(value: value)

    if self.prefersChapterContext,
       let currentChapter = self.chapterBeforeSliderValueChange {
      newCurrentTime = TimeInterval(value) * currentChapter.duration
    }

    var newMaxTime: TimeInterval?

    if self.prefersRemainingTime {
      let durationTimeInContext = self.playerManager.currentBook?.durationTimeInContext(self.prefersChapterContext) ?? 0

      newMaxTime = newCurrentTime - durationTimeInContext
    }

    var progress: String?

    if !(self.playerManager.currentBook?.hasChapters ?? false) || !self.prefersChapterContext {
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
    return self.playerManager.currentBook?.maxTimeInContext(self.prefersChapterContext, self.prefersRemainingTime) ?? 0
  }

  func getBookTimeFromSlider(value: Float) -> TimeInterval {
    var newTimeToDisplay = TimeInterval(value) * (self.playerManager.currentBook?.duration ?? 0)

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

  func getSpeedActionSheet() -> UIAlertController {
    let actionSheet = UIAlertController(title: nil, message: "player_speed_title".localized, preferredStyle: .actionSheet)

    for speed in SpeedManager.shared.speedOptions {
      if speed ==  SpeedManager.shared.getSpeed() {
        actionSheet.addAction(UIAlertAction(title: "\u{00A0} \(speed) ✓", style: .default, handler: nil))
      } else {
        actionSheet.addAction(UIAlertAction(title: "\(speed)", style: .default, handler: { _ in
          SpeedManager.shared.setSpeed(speed, currentBook: self.playerManager.currentBook)
          self.dataManager.saveContext()
        }))
      }
    }

    actionSheet.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))

    return actionSheet
  }

  func showChapters() {
    self.coordinator.showChapters()
  }

  func dismiss() {
    self.coordinator.dismiss()
  }
}

extension PlayerViewModel {
  func showBookmarks() {
    self.coordinator.showBookmarks()
  }

  func createBookmark(vc: UIViewController) {
    guard let book = self.playerManager.currentBook else { return }

    let currentTime = book.currentTime

    if let bookmark = self.dataManager.getBookmark(at: currentTime, book: book, type: .user) {
      self.showBookmarkSuccessAlert(vc: vc, bookmark: bookmark, existed: true)
      return
    }

    let bookmark = self.dataManager.createBookmark(at: currentTime, book: book, type: .user)

    self.showBookmarkSuccessAlert(vc: vc, bookmark: bookmark, existed: false)
  }

  func showBookmarkSuccessAlert(vc: UIViewController, bookmark: Bookmark, existed: Bool) {
    let formattedTime = TimeParser.formatTime(bookmark.time)

    let titleKey = existed
      ? "bookmark_exists_title"
      : "bookmark_created_title"

    let alert = UIAlertController(title: String.localizedStringWithFormat(titleKey.localized, formattedTime),
                                  message: nil,
                                  preferredStyle: .alert)

    if !existed {
      alert.addAction(UIAlertAction(title: "bookmark_note_action_title".localized, style: .default, handler: { _ in
        self.showBookmarkNoteAlert(vc: vc, bookmark: bookmark)
      }))
    }

    alert.addAction(UIAlertAction(title: "bookmarks_see_title".localized, style: .default, handler: { _ in
      self.showBookmarks()
    }))

    alert.addAction(UIAlertAction(title: "ok_button".localized, style: .cancel, handler: nil))

    vc.present(alert, animated: true, completion: nil)
  }

  func showBookmarkNoteAlert(vc: UIViewController, bookmark: Bookmark) {
    let alert = UIAlertController(title: "bookmark_note_action_title".localized,
                                  message: nil,
                                  preferredStyle: .alert)

    alert.addTextField(configurationHandler: { textfield in
      textfield.text = ""
    })

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "ok_button".localized, style: .default, handler: { _ in
      guard let note = alert.textFields?.first?.text else {
        return
      }

      self.dataManager.addNote(note, bookmark: bookmark)
    }))

    vc.present(alert, animated: true, completion: nil)
  }
}
