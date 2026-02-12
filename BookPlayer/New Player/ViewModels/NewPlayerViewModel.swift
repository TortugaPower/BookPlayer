//
//  NewPlayerViewModel.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 10/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI

@MainActor
final class NewPlayerViewModel: ObservableObject {
  @State var progressData = ProgressData()
  @Published var isPlaying = false
  @Published var relativePath: String?
  @Published var currentAlert: BPAlertContent?
  @Published var isShowingChapters: Bool = false
  @Published var isShowingControls: Bool = false
  @Published var isShowingButtonFree: Bool = false
  @Published var isShowingBookmark: Bool = false
  @Published var isShowingTimer: Bool = false
  
  let libraryService: LibraryService
  let playbackService: PlaybackService
  let playerManager: PlayerManager
  let syncService: SyncService
  private var chapterBeforeSliderValueChange: PlayableChapter?
  private let sharedDefaults: UserDefaults
  private var prefersChapterContext: Bool
  private var prefersRemainingTime: Bool
  
  private var disposeBag = Set<AnyCancellable>()
  private var playingProgressSubscriber: AnyCancellable?
  private var currentChapterSubscriber: AnyCancellable?
  private var updateProgressObserver: NSKeyValueObservation?
  
  func hasChapter(before chapter: PlayableChapter?) -> Bool {
    guard let chapter = chapter else { return false }
    return self.playerManager.currentItem?.hasChapter(before: chapter) ?? false
  }
  
  func hasChapter(after chapter: PlayableChapter?) -> Bool {
    guard let chapter = chapter else { return false }
    return self.playerManager.currentItem?.hasChapter(after: chapter) ?? false
  }
  
  init(
    libraryService: LibraryService,
    playbackService: PlaybackService,
    playerManager: PlayerManager,
    syncService: SyncService,
  ) {
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.playerManager = playerManager
    self.syncService = syncService
    let sharedDefaults = UserDefaults.sharedDefaults
    self.prefersChapterContext = sharedDefaults.bool(forKey: Constants.UserDefaults.chapterContextEnabled)
    self.prefersRemainingTime = sharedDefaults.bool(forKey: Constants.UserDefaults.remainingTimeEnabled)
    self.sharedDefaults = sharedDefaults
    
    bindBookPlayingProgressEvents()
  }
  
  func bindBookPlayingProgressEvents() {
    self.playingProgressSubscriber?.cancel()
    self.playingProgressSubscriber = NotificationCenter.default.publisher(for: .bookPlaying)
      .sink { [weak self] _ in
        guard let self = self else { return }
        self.recalculateProgress()
      }
    
    self.playerManager.isPlayingPublisher()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isPlaying in
        self?.isPlaying = isPlaying
      }
      .store(in: &disposeBag)
    
    self.playerManager.currentItemPublisher()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] item in
        self?.currentChapterSubscriber?.cancel()
        guard let self = self,
              let item = item
        else { return }
        
        bindCurrentChapter(for: item)
      }.store(in: &disposeBag)
  }
  
  func bindCurrentChapter(for item: PlayableItem) {
    currentChapterSubscriber = item.$currentChapter
      .receive(on: DispatchQueue.main)
      .sink { [weak self, item] chapter in
        let relativePath: String
        
        if let chapter,
           ArtworkService.isCached(relativePath: chapter.relativePath)
        {
          relativePath = chapter.relativePath
        } else {
          relativePath = item.relativePath
        }
        
        self?.relativePath = relativePath
      }
  }
  
  func getBookCurrentTime() -> TimeInterval {
    return self.playerManager.currentItem?.currentTimeInContext(self.prefersChapterContext) ?? 0
  }
  
  func getBookMaxTime() -> TimeInterval {
    return self.playerManager.currentItem?.maxTimeInContext(
      prefersChapterContext: self.prefersChapterContext,
      prefersRemainingTime: self.prefersRemainingTime,
      at: self.playerManager.currentSpeed
    ) ?? 0
  }
  
  func processToggleMaxTime() {
    self.prefersRemainingTime = !self.prefersRemainingTime
    sharedDefaults.set(self.prefersRemainingTime, forKey: Constants.UserDefaults.remainingTimeEnabled)
    
    self.recalculateProgress()
  }
  
  func processToggleProgressState() {
    self.prefersChapterContext = !self.prefersChapterContext
    sharedDefaults.set(self.prefersChapterContext, forKey: Constants.UserDefaults.chapterContextEnabled)
    
    self.recalculateProgress()
  }
  
  func handleSliderUpEvent(with value: Float) {
    let newTime = getBookTimeFromSlider(value: value)
    
    self.playerManager.jumpTo(newTime, recordBookmark: true)
  }
  
  func getBookTimeFromSlider(value: Float) -> TimeInterval {
    var newTimeToDisplay = TimeInterval(value) * (self.playerManager.currentItem?.duration ?? 0)
    
    if self.prefersChapterContext,
       let currentChapter = self.chapterBeforeSliderValueChange
    {
      newTimeToDisplay = currentChapter.start + TimeInterval(value) * currentChapter.duration
    }
    
    return newTimeToDisplay
  }
  
  func recalculateProgress() {
    let currentTime = self.getBookCurrentTime()
    let maxTimeInContext = self.getBookMaxTime()
    let progress: String
    let sliderValue: Float
    
    let currentItem = self.playerManager.currentItem
    
    if self.prefersChapterContext,
       let currentItem = currentItem,
       let currentChapter = currentItem.currentChapter
    {
      progress = String.localizedStringWithFormat(
        "player_chapter_description".localized,
        currentChapter.index,
        currentItem.chapters.count
      )
      sliderValue = Float((currentItem.currentTime - currentChapter.start) / currentChapter.duration)
    } else {
      progress = "\(Int(round((currentItem?.progressPercentage ?? 0) * 100)))%"
      sliderValue = Float(currentItem?.progressPercentage ?? 0)
    }
    
    // Update local chapter
    self.chapterBeforeSliderValueChange = currentItem?.currentChapter
    
    progressData.chapterTitle = currentItem?.currentChapter?.title
    ?? currentItem?.title
    ?? ""
    progressData.progress = progress
    progressData.maxTime = maxTimeInContext
    progressData.currentTime = currentTime
    progressData.sliderValue = Double(sliderValue)
  }
  
  func hasLoadedBook() -> Bool {
    return self.playerManager.hasLoadedBook()
  }
  
  func handleSleepTimerTap(media: MediaAction) {
    switch media {
      case .bookmark:
        createBookmark()
      case .more:
        setMoreAlert()
      case .chapters:
        isShowingChapters = !isShowingChapters
      case .speed:
        isShowingControls = !isShowingControls
      case .timer:
        self.setSleepTimerAlert()
    }
  }
  
  func getCountdownActions() -> [BPActionItem] {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .full
    formatter.allowedUnits = [.hour, .minute]

    return SleepTimer.shared.intervals.compactMap { interval in
      guard let formattedDuration = formatter.string(from: interval) else { return nil }

      return BPActionItem(
        title: String.localizedStringWithFormat("sleep_interval_title".localized, formattedDuration),
        handler: {
          SleepTimer.shared.setTimer(.countdown(interval))
        }
      )
    }
  }
  
  func setSleepTimerAlert() {
    var actions = [BPActionItem]()

    actions.append(
      BPActionItem(
        title: "sleep_off_title".localized,
        handler: {
          SleepTimer.shared.setTimer(.off)
        }
      )
    )

    actions.append(contentsOf: getCountdownActions())

    actions.append(
      BPActionItem(
        title: "sleep_chapter_option_title".localized,
        handler: {
          SleepTimer.shared.setTimer(.endOfChapter)
        }
      )
    )

    actions.append(
      BPActionItem(
        title: "sleeptimer_option_custom".localized,
        handler: { [weak self] in
          print("NONES")
        }
      )
    )

    actions.append(BPActionItem.cancelAction)
  
    currentAlert = BPAlertContent(
      title: "TEXT",
      message: "sleep_alert_description".localized,
      style: .actionSheet,
      actionItems: actions
    )
  }
  
  func getListTitleForMoreAction() -> String {
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks) {
      return "chapters_title".localized
    } else {
      return "bookmarks_title".localized
    }
  }
  
  func isBookFinished() -> Bool {
    return self.playerManager.currentItem?.isFinished ?? false
  }
  
  func handleJumpToStart() {
    self.playerManager.pause()
    self.playerManager.jumpTo(0.0, recordBookmark: false)
  }

  func handleMarkCompletion() {
    self.playerManager.pause()
    self.playerManager.markAsCompleted(!self.isBookFinished())
  }
  
  func isRepeatEnabled() -> Bool {
    guard let currentItem = self.playerManager.currentItem else { return false }
    return UserDefaults.standard.bool(
      forKey: currentItem.filename + Constants.UserDefaults.repeatEnabledSuffix
    )
  }

  func handleEnableRepeat() {
    guard let filename = self.playerManager.currentItem?.filename else { return }
    UserDefaults.standard.set(
      !isRepeatEnabled(),
      forKey: filename + Constants.UserDefaults.repeatEnabledSuffix
    )
  }

  func handlePreviousChapterAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    if let currentChapter = self.playerManager.currentItem?.currentChapter,
      let previousChapter = self.playerManager.currentItem?.previousChapter(before: currentChapter)
    {
      self.playerManager.jumpToChapter(previousChapter)
      //sendEvent(.updateProgress(getCurrentProgressState()))
    } else {
      self.playerManager.playPreviousItem()
    }
  }

  func handleNextChapterAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    if let currentChapter = self.playerManager.currentItem?.currentChapter,
      let nextChapter = self.playerManager.currentItem?.nextChapter(after: currentChapter)
    {
      self.playerManager.jumpToChapter(nextChapter)
      //sendEvent(.updateProgress(getCurrentProgressState()))
    } else {
      self.playerManager.playNextItem(autoPlayed: false, shouldAutoplay: true)
    }
  }
  
  func resetShowings() {
    isShowingChapters = false
    isShowingControls = false
    isShowingButtonFree = false
    isShowingBookmark = false
    isShowingTimer = false
  }
  
  func showListFromMoreAction() {
    resetShowings()
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks) {
      isShowingChapters = true
    } else {
      isShowingBookmark = true
    }
  }
  
  func setMoreAlert() {
    guard self.hasLoadedBook() else { return }


    let markTitle =
      self.isBookFinished() ? "mark_unfinished_title".localized : "mark_finished_title".localized
    
    var actions = [BPActionItem]()

    actions.append(
      BPActionItem(
        title: self.getListTitleForMoreAction(),
        handler: { self.showListFromMoreAction() }
      )
    )
    
    actions.append(
      BPActionItem(
        title: "jump_start_title".localized,
        handler: { self.handleJumpToStart() }
      )
    )
    
    actions.append(
      BPActionItem(
        title: markTitle,
        handler: { self.handleMarkCompletion() }
      )
    )
    
    actions.append(
      BPActionItem(
        title: "button_free_title".localized,
        handler: { self.showButtonFree() }
      )
    )
    
    actions.append(
      BPActionItem(
        title: self.isRepeatEnabled()
          ? "repeat_turn_off_title".localized : "repeat_turn_on_title".localized,
        handler: { self.handleEnableRepeat() }
      )
    )
    
    currentAlert = BPAlertContent(
      title: "",
      message: "",
      style: .actionSheet,
      actionItems: actions
    )
  }
  
  func showButtonFree() {
    isShowingButtonFree = true
  }
  
  func createBookmark() {
    guard let currentItem = self.playerManager.currentItem else { return }

    let currentTime = currentItem.currentTime

    if let bookmark = self.libraryService.getBookmark(
      at: currentTime,
      relativePath: currentItem.relativePath,
      type: .user
    ) {
      self.showBookmarkSuccessAlert(bookmark: bookmark, existed: true)
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
      self.showBookmarkSuccessAlert(bookmark: bookmark, existed: false)
    } else {
      //vc.showAlert("error_title".localized, message: "file_missing_title".localized)
    }
  }
  
  func showBookmarkSuccessAlert(bookmark: SimpleBookmark, existed: Bool) {
    var actions = [BPActionItem]()
    let formattedTime = TimeParser.formatTime(bookmark.time)

    let titleKey =
      existed
      ? "bookmark_exists_title"
      : "bookmark_created_title"
    
    if !existed {
      actions.append(
        BPActionItem(
          title: "bookmark_note_action_title".localized,
          handler: {
            //self?.showBookmarkNoteAlert(vc: vc, bookmark: bookmark)
          }
        )
      )
    }
    
    actions.append(
      BPActionItem(
        title: "bookmarks_see_title".localized,
        handler: {
          self.isShowingBookmark = true
        }
      )
    )
    
    currentAlert = BPAlertContent(
      title: String.localizedStringWithFormat(titleKey.localized, formattedTime),
      message: "".localized,
      style: .alert,
      actionItems: actions
    )
  }
}
