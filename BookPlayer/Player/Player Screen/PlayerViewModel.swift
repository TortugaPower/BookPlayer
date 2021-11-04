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

class PlayerViewModel: BaseViewModel<PlayerCoordinator> {
  private let playerManager: PlayerManager
  private let dataManager: DataManager
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

  func hasChapter(before chapter: Chapter?) -> Bool {
    guard let chapter = chapter else { return false }
    return self.playerManager.currentBook?.hasChapter(before: chapter) ?? false
  }

  func hasChapter(after chapter: Chapter?) -> Bool {
    guard let chapter = chapter else { return false }
    return self.playerManager.currentBook?.hasChapter(after: chapter) ?? false
  }

  func handlePreviousChapterAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    if let currentChapter = self.playerManager.currentBook?.currentChapter,
       let previousChapter = self.playerManager.currentBook?.previousChapter(before: currentChapter) {
      self.playerManager.jumpTo(previousChapter.start + 0.5)
    } else {
      self.playerManager.playPreviousItem()
    }
  }

  func handleNextChapterAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    if let currentChapter = self.playerManager.currentBook?.currentChapter,
       let nextChapter = self.playerManager.currentBook?.nextChapter(after: currentChapter) {
      self.playerManager.jumpTo(nextChapter.start + 0.5)
    } else {
      self.playerManager.playNextItem()
    }
  }

  func isBookFinished() -> Bool {
    return self.playerManager.currentBook?.isFinished ?? false
  }

  func getBookCurrentTime() -> TimeInterval {
    return self.playerManager.currentBook?.currentTimeInContext(self.prefersChapterContext) ?? 0
  }

  func getCurrentTimeVoiceOverPrefix() -> String {
    return self.prefersChapterContext
    ? "voiceover_chapter_time_title".localized
    : "book_time_current_title".localized
  }

  func getMaxTimeVoiceOverPrefix() -> String {
    if self.prefersChapterContext {
      return self.prefersRemainingTime
      ? "chapter_time_remaining_title".localized
      : "chapter_duration_title".localized
    }

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

  func getCurrentProgressState(_ book: Book? = nil) -> ProgressObject {
    let currentTime = self.getBookCurrentTime()
    let maxTimeInContext = self.getBookMaxTime()
    let progress: String
    let sliderValue: Float

    let currentBook = book ?? self.playerManager.currentBook

    if self.prefersChapterContext,
       let currentBook = currentBook,
       currentBook.hasChapters,
       let chapters = currentBook.chapters,
       let currentChapter = currentBook.currentChapter {
      progress = String.localizedStringWithFormat("player_chapter_description".localized, currentChapter.index, chapters.count)
      sliderValue = Float((currentBook.currentTime - currentChapter.start) / currentChapter.duration)
    } else {
      progress = "\(Int(round((currentBook?.progressPercentage ?? 0) * 100)))%"
      sliderValue = Float(currentBook?.progressPercentage ?? 0)
    }

    // Update local chapter
    self.chapterBeforeSliderValueChange = currentBook?.currentChapter

    let prevChapterImageName = self.hasChapter(before: currentBook?.currentChapter)
    ? "chevron.left"
    : "chevron.left.2"
    let nextChapterImageName = self.hasChapter(after: currentBook?.currentChapter)
    ? "chevron.right"
    : "chevron.right.2"

    return ProgressObject(
      currentTime: currentTime,
      progress: progress,
      maxTime: maxTimeInContext,
      sliderValue: sliderValue,
      prevChapterImageName: prevChapterImageName,
      nextChapterImageName: nextChapterImageName,
      chapterTitle: currentBook?.currentChapter?.title
      ?? currentBook?.title
      ?? ""
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
    var chapterTitle: String?
    var prevChapterImageName = "chevron.left.2"
    var nextChapterImageName = "chevron.right.2"
    var newCurrentTime: TimeInterval
    if self.prefersChapterContext,
       let currentChapter = self.chapterBeforeSliderValueChange {
      newCurrentTime = TimeInterval(value) * currentChapter.duration
      chapterTitle = currentChapter.title

      if self.hasChapter(before: currentChapter) {
        prevChapterImageName = "chevron.left"
      }
      if self.hasChapter(after: currentChapter) {
        nextChapterImageName = "chevron.right"
      }
    } else {
      newCurrentTime = self.getBookTimeFromSlider(value: value)
      if let chapter = self.playerManager.currentBook?.getChapter(at: newCurrentTime) {
        chapterTitle = chapter.title

        if self.hasChapter(before: chapter) {
          prevChapterImageName = "chevron.left"
        }
        if self.hasChapter(after: chapter) {
          nextChapterImageName = "chevron.right"
        }
      }
    }

    var progress: String?
    if !self.playerManager.hasChapters.value || !self.prefersChapterContext {
      progress = "\(Int(round(value * 100)))%"
    }

    var newMaxTime: TimeInterval?
    if self.prefersRemainingTime {
      let durationTimeInContext = self.playerManager.currentBook?.durationTimeInContext(self.prefersChapterContext) ?? 0

      newMaxTime = newCurrentTime - durationTimeInContext
    }

    return ProgressObject(
      currentTime: newCurrentTime,
      progress: progress,
      maxTime: newMaxTime,
      sliderValue: value,
      prevChapterImageName: prevChapterImageName,
      nextChapterImageName: nextChapterImageName,
      chapterTitle: chapterTitle ?? self.chapterBeforeSliderValueChange?.title
      ?? self.playerManager.currentBook?.title
      ?? ""
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
    self.coordinator.didFinish()
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
