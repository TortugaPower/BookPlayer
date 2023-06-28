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

class PlayerViewModel: BaseViewModel<PlayerCoordinator> {
  enum Events {
    case sleepTimerAlert(content: BPAlertContent)
    case customSleepTimer(title: String)
  }

  private let playerManager: PlayerManagerProtocol
  private let libraryService: LibraryServiceProtocol
  private let syncService: SyncServiceProtocol
  private var chapterBeforeSliderValueChange: PlayableChapter?
  private var prefersChapterContext = UserDefaults.standard.bool(forKey: Constants.UserDefaults.chapterContextEnabled)
  private var prefersRemainingTime = UserDefaults.standard.bool(forKey: Constants.UserDefaults.remainingTimeEnabled)

  var eventsPublisher = InterfaceUpdater<PlayerViewModel.Events>()

  init(
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
  }

  private func sendEvent(_ event: PlayerViewModel.Events) {
    eventsPublisher.send(event)
  }

  func currentItemObserver() -> AnyPublisher<PlayableItem?, Never> {
    return self.playerManager.currentItemPublisher()
  }

  func currentSpeedObserver() -> AnyPublisher<Float, Never> {
    return self.playerManager.currentSpeedPublisher()
  }

  func isPlayingObserver() -> AnyPublisher<Bool, Never> {
    return self.playerManager.isPlayingPublisher()
  }

  func hasLoadedBook() -> Bool {
    return self.playerManager.hasLoadedBook()
  }

  func hasChapter(before chapter: PlayableChapter?) -> Bool {
    guard let chapter = chapter else { return false }
    return self.playerManager.currentItem?.hasChapter(before: chapter) ?? false
  }

  func hasChapter(after chapter: PlayableChapter?) -> Bool {
    guard let chapter = chapter else { return false }
    return self.playerManager.currentItem?.hasChapter(after: chapter) ?? false
  }

  func handlePreviousChapterAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    if let currentChapter = self.playerManager.currentItem?.currentChapter,
       let previousChapter = self.playerManager.currentItem?.previousChapter(before: currentChapter) {
      self.playerManager.jumpToChapter(previousChapter)
    } else {
      self.playerManager.playPreviousItem()
    }
  }

  func handleNextChapterAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    if let currentChapter = self.playerManager.currentItem?.currentChapter,
       let nextChapter = self.playerManager.currentItem?.nextChapter(after: currentChapter) {
      self.playerManager.jumpToChapter(nextChapter)
    } else {
      self.playerManager.playNextItem(autoPlayed: false)
    }
  }

  func isBookFinished() -> Bool {
    return self.playerManager.currentItem?.isFinished ?? false
  }

  func getBookCurrentTime() -> TimeInterval {
    return self.playerManager.currentItem?.currentTimeInContext(self.prefersChapterContext) ?? 0
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
    self.playerManager.pause(fade: false)
    self.playerManager.jumpTo(0.0, recordBookmark: false)
  }

  func handleMarkCompletion() {
    self.playerManager.pause(fade: false)
    self.playerManager.markAsCompleted(!self.isBookFinished())
  }

  func processToggleMaxTime() -> ProgressObject {
    self.prefersRemainingTime = !self.prefersRemainingTime
    UserDefaults.standard.set(self.prefersRemainingTime, forKey: Constants.UserDefaults.remainingTimeEnabled)

    return self.getCurrentProgressState()
  }

  func processToggleProgressState() -> ProgressObject {
    self.prefersChapterContext = !self.prefersChapterContext
    UserDefaults.standard.set(self.prefersChapterContext, forKey: Constants.UserDefaults.chapterContextEnabled)

    return self.getCurrentProgressState()
  }

  func getCurrentProgressState(_ item: PlayableItem? = nil) -> ProgressObject {
    let currentTime = self.getBookCurrentTime()
    let maxTimeInContext = self.getBookMaxTime()
    let progress: String
    let sliderValue: Float

    let currentItem = item ?? self.playerManager.currentItem

    if self.prefersChapterContext,
       let currentItem = currentItem,
       let currentChapter = currentItem.currentChapter {
      progress = String.localizedStringWithFormat("player_chapter_description".localized, currentChapter.index, currentItem.chapters.count)
      sliderValue = Float((currentItem.currentTime - currentChapter.start) / currentChapter.duration)
    } else {
      progress = "\(Int(round((currentItem?.progressPercentage ?? 0) * 100)))%"
      sliderValue = Float(currentItem?.progressPercentage ?? 0)
    }

    // Update local chapter
    self.chapterBeforeSliderValueChange = currentItem?.currentChapter

    let prevChapterImageName = self.hasChapter(before: currentItem?.currentChapter)
    ? "chevron.left"
    : "chevron.left.2"
    let nextChapterImageName = self.hasChapter(after: currentItem?.currentChapter)
    ? "chevron.right"
    : "chevron.right.2"

    return ProgressObject(
      currentTime: currentTime,
      progress: progress,
      maxTime: maxTimeInContext,
      sliderValue: sliderValue,
      prevChapterImageName: prevChapterImageName,
      nextChapterImageName: nextChapterImageName,
      chapterTitle: currentItem?.currentChapter?.title
      ?? currentItem?.title
      ?? ""
    )
  }

  func handleSliderDownEvent() {
    self.chapterBeforeSliderValueChange = self.playerManager.currentItem?.currentChapter
  }

  func handleSliderUpEvent(with value: Float) {
    let newTime = getBookTimeFromSlider(value: value)

    self.playerManager.jumpTo(newTime, recordBookmark: true)
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
      if let chapter = self.playerManager.currentItem?.getChapter(at: newCurrentTime) {
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
    if !self.prefersChapterContext {
      progress = "\(Int(round(value * 100)))%"
    }

    var newMaxTime: TimeInterval?
    if self.prefersRemainingTime {
      let durationTimeInContext = self.playerManager.currentItem?.durationTimeInContext(self.prefersChapterContext) ?? 0

      newMaxTime = (newCurrentTime - durationTimeInContext) / Double(self.playerManager.currentSpeed)
    }

    return ProgressObject(
      currentTime: newCurrentTime,
      progress: progress,
      maxTime: newMaxTime,
      sliderValue: value,
      prevChapterImageName: prevChapterImageName,
      nextChapterImageName: nextChapterImageName,
      chapterTitle: chapterTitle ?? self.chapterBeforeSliderValueChange?.title
      ?? self.playerManager.currentItem?.title
      ?? ""
    )
  }

  func getBookMaxTime() -> TimeInterval {
    return self.playerManager.currentItem?.maxTimeInContext(
      prefersChapterContext: self.prefersChapterContext,
      prefersRemainingTime: self.prefersRemainingTime,
      at: self.playerManager.currentSpeed
    ) ?? 0
  }

  func getBookTimeFromSlider(value: Float) -> TimeInterval {
    var newTimeToDisplay = TimeInterval(value) * (self.playerManager.currentItem?.duration ?? 0)

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
    AppDelegate.shared?.requestReview()
#endif

    UserDefaults.standard.set(false, forKey: "ask_review")
  }

  func showList() {
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks) {
      self.coordinator.showBookmarks()
    } else {
      self.coordinator.showChapters()
    }
  }

  func showListFromMoreAction() {
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks) {
      self.coordinator.showChapters()
    } else {
      self.coordinator.showBookmarks()
    }
  }

  func getListTitleForMoreAction() -> String {
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks) {
      return "chapters_title".localized
    } else {
      return "bookmarks_title".localized
    }
  }

  func showControls() {
    self.coordinator.showControls()
  }

  func showSleepTimerActions() {
    var actions = [BPActionItem]()

    actions.append(
      BPActionItem(
        title: "sleep_off_title".localized,
        handler: { [weak self] in
          self?.handleSleepTimerOptions(seconds: -1)
        }
      )
    )

    let formatter = DateComponentsFormatter()

    formatter.unitsStyle = .full
    formatter.allowedUnits = [.hour, .minute]

    for interval in SleepTimer.shared.intervals {
      guard let formattedDuration = formatter.string(from: interval) else { continue }

      actions.append(
        BPActionItem(
          title: String.localizedStringWithFormat("sleep_interval_title".localized, formattedDuration),
          handler: { [weak self] in
            self?.handleSleepTimerOptions(seconds: interval)
          }
        )
      )
    }

    actions.append(
      BPActionItem(
        title: "sleep_chapter_option_title".localized,
        handler: { [weak self] in
          self?.handleSleepTimerOptions(seconds: -2)
        }
      )
    )

    actions.append(
      BPActionItem(
        title: "sleeptimer_option_custom".localized,
        handler: { [weak self] in
          self?.showCustomSleepTimerOption()
        }
      )
    )

    actions.append(BPActionItem.cancelAction)

    sendEvent(.sleepTimerAlert(
      content: BPAlertContent(
        title: nil,
        message: SleepTimer.shared.getAlertMessage(),
        style: .actionSheet,
        actionItems: actions
      )
    ))
  }

  func showCustomSleepTimerOption() {
    sendEvent(.customSleepTimer(title: "sleeptimer_custom_alert_title".localized))
  }

  func handleSleepTimerOptions(seconds: Double) {
    guard let option = TimeParser.getTimerOption(from: seconds) else {
      SleepTimer.shared.sleep(in: seconds)
      return
    }

    SleepTimer.shared.sleep(in: option)
  }
}

extension PlayerViewModel {
  func showBookmarks() {
    self.coordinator.showBookmarks()
  }

  func createBookmark(vc: UIViewController) {
    guard let currentItem = self.playerManager.currentItem else { return }

    let currentTime = currentItem.currentTime

    if let bookmark = self.libraryService.getBookmark(
      at: currentTime,
      relativePath: currentItem.relativePath,
      type: .user
    ) {
      self.showBookmarkSuccessAlert(vc: vc, bookmark: bookmark, existed: true)
      return
    }

    if let bookmark = self.libraryService.createBookmark(
      at: floor(currentTime),
      relativePath: currentItem.relativePath,
      type: .user
    ) {
      syncService.scheduleSetBookmark(
        relativePath: currentItem.relativePath,
        time: floor(currentTime),
        note: nil
      )
      self.showBookmarkSuccessAlert(vc: vc, bookmark: bookmark, existed: false)
    } else {
      vc.showAlert("error_title".localized, message: "file_missing_title".localized)
    }
  }

  func showBookmarkSuccessAlert(vc: UIViewController, bookmark: SimpleBookmark, existed: Bool) {
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

  func showBookmarkNoteAlert(vc: UIViewController, bookmark: SimpleBookmark) {
    let alert = UIAlertController(title: "bookmark_note_action_title".localized,
                                  message: nil,
                                  preferredStyle: .alert)

    alert.addTextField(configurationHandler: { textfield in
      textfield.text = ""
    })

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "ok_button".localized, style: .default, handler: { [weak self] _ in
      guard let note = alert.textFields?.first?.text else {
        return
      }

      self?.libraryService.addNote(note, bookmark: bookmark)
      self?.syncService.scheduleSetBookmark(
        relativePath: bookmark.relativePath,
        time: bookmark.time,
        note: note
      )
    }))

    vc.present(alert, animated: true, completion: nil)
  }
}

extension PlayerViewModel {
  func showButtonFree() {
    self.coordinator.showButtonFree()
  }
}
