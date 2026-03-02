//
//  PlayerViewModel.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 10/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI

enum PlayerSheetStyle: String, Identifiable {
    case chapters
    case controls
    case buttonFree
    case bookmark
    case sleep

    var id: String { self.rawValue }
}

enum BPTranscriptError: LocalizedError {
    case noBookLoaded

    var errorDescription: String? {
        switch self {
        case .noBookLoaded:
            return "No book is currently loaded."
        }
    }
}

@MainActor
final class PlayerViewModel: ObservableObject {
  @Published var progressData = ProgressData()
  @Published var isPlaying = false
  @Published var playbackSpeed: Float = 1.0
  @Published var title = "voiceover_unknown_title".localized
  @Published var author = "voiceover_unknown_title".localized
  @Published var relativePath: String?
  @Published var artworkUrl: URL?
  @Published var currentAlert: BPAlertContent?
  @Published var currentAlertOrigin: MediaAction?
  @Published var sleepText: String?
  @Published var hasNextChapter = false
  @Published var hasPreviousChapter = false
  @Published var isShowingNote: Bool = false
  @Published var sheetStyle: PlayerSheetStyle?
  @Published var displaySheet = false
  @Published var transcriptLines = [TranscriptLine]()
  @Published var activeTranscriptIndex: Int?
  @Published var isShowingTranscript = false
  
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let playerManager: PlayerManagerProtocol
  let syncService: SyncServiceProtocol
  
  private var chapterBeforeSliderValueChange: PlayableChapter?
  private let sharedDefaults: UserDefaults
  private var prefersChapterContext: Bool
  private var prefersRemainingTime: Bool
  private var lastBookmark: SimpleBookmark?
  private var disposeBag = Set<AnyCancellable>()
  private var playingProgressSubscriber: AnyCancellable?
  private var listeningProgressSubscriber: AnyCancellable?
  private var currentChapterSubscriber: AnyCancellable?
  private var progressUpdateObserver: NSKeyValueObservation?
  private let transcriptStore = TranscriptStore()
  
  var currentTimeAccessLabel: String {
    let prefix = self.prefersChapterContext
      ? "voiceover_chapter_time_title".localized
      : "book_time_current_title".localized
    return String.localizedStringWithFormat(
      prefix,
      VoiceOverService.secondsToMinutes(progressData.currentTime)
    )
  }
  
  var remainingTimeAccessLabel: String {
    guard let maxTime = progressData.maxTime else {
      return "\(self.getMaxTimeVoiceOverPrefix())"
    }
    
    return "\(self.getMaxTimeVoiceOverPrefix()) \(VoiceOverService.secondsToMinutes(maxTime))"
  }

  var hasTranscript: Bool {
    return !transcriptLines.isEmpty
  }
  
  func formattedSpeed() -> String {
    return (playbackSpeed.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(playbackSpeed))" : "\(playbackSpeed)") + "×"
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
    syncService: SyncService
  ) {
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.playerManager = playerManager
    self.syncService = syncService
    let sharedDefaults = UserDefaults.sharedDefaults
    self.prefersChapterContext = sharedDefaults.bool(forKey: Constants.UserDefaults.chapterContextEnabled)
    self.prefersRemainingTime = sharedDefaults.bool(forKey: Constants.UserDefaults.remainingTimeEnabled)
    self.sharedDefaults = sharedDefaults
  }
  
  func bindBookObservers() {
    bindBookPlayingProgressEvents()
    bindNotificationSubscribers()
    bindBookSharedObservers()
  }
  
  func bindBookSharedObservers() {
    UserDefaults.standard.set(false, forKey: Constants.UserDefaults.updateProgress)
    
    progressUpdateObserver = UserDefaults.standard.observe(
      \.userSettingsUpdateProgress,
       options: [.new]
    ) { [weak self] object, change in

      guard let self,
            let newValue = change.newValue,
            newValue == true
      else { return }
      
      Task { @MainActor in
        self.prefersChapterContext = UserDefaults.sharedDefaults.bool(forKey: Constants.UserDefaults.chapterContextEnabled)
        self.prefersRemainingTime = UserDefaults.sharedDefaults.bool(forKey: Constants.UserDefaults.remainingTimeEnabled)
        self.recalculateProgress()
      }
      
      object.set(false, forKey: Constants.UserDefaults.updateProgress)
    }
    
    SleepTimer.shared.$state
      .map { [weak self] state -> String? in
        switch state {
        case .off:
          return nil
        case .endOfChapter:
          return "active_title".localized
        case .countdown(let seconds):
          return self?.durationFormatter.string(from: seconds)
        }
      }
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
      .sink { [weak self] toolbarDescription in
        guard let self else { return }

        if let timeFormatted = toolbarDescription {
          sleepText = timeFormatted
        } else {
          sleepText = nil
        }
      }.store(in: &disposeBag)
  }
  
  func bindNotificationSubscribers() {
    NotificationCenter.default.publisher(for: .requestReview)
      .debounce(for: 1.0, scheduler: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.requestReview()
      }
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .bookEnd)
      .debounce(for: 1.0, scheduler: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.requestReview()
      }
      .store(in: &disposeBag)
    
    NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
      .debounce(for: 1.0, scheduler: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.handleAutolockStatus()
      }
      .store(in: &disposeBag)
  }
  
  func bindBookPlayingProgressEvents() {
    self.playerManager.isPlayingPublisher()
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isPlaying in
        self?.isPlaying = isPlaying
      }
      .store(in: &disposeBag)
    
    self.playerManager.currentItemPublisher()
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] item in
        self?.currentChapterSubscriber?.cancel()
        guard let self = self else { return }

        guard let item else {
          self.resetTranscriptState()
          return
        }

        self.loadTranscriptIfAvailable(for: item)
        bindCurrentChapter(for: item)
      }.store(in: &disposeBag)
    
    self.playerManager.currentSpeedPublisher()
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] speed in
        guard let self = self else { return }

        self.playbackSpeed = speed
        self.recalculateProgress()
      }
      .store(in: &disposeBag)
    
    self.playingProgressSubscriber?.cancel()
    self.playingProgressSubscriber = NotificationCenter.default.publisher(for: .bookPlaying)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self = self else { return }
        self.recalculateProgress()
        self.updateTranscriptPosition()
      }
    
    self.listeningProgressSubscriber?.cancel()
    self.listeningProgressSubscriber = NotificationCenter.default.publisher(for: .listeningProgressChanged)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self = self else { return }
        self.recalculateProgress()
        self.updateTranscriptPosition()
      }
  }
  
  private lazy var durationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .positional
    formatter.allowedUnits = [.minute, .second]
    formatter.collapsesLargestUnit = true
    return formatter
  }()
  
  func bindCurrentChapter(for item: PlayableItem) {
    currentChapterSubscriber = item.$currentChapter
      .receive(on: DispatchQueue.main)
      .sink { [weak self, item] chapter in
        let relativePath: String
        
        self?.title = item.title
        self?.author = item.author
        
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
  
  func displaySheet(style: PlayerSheetStyle) {
    self.sheetStyle = style
    self.displaySheet = true
  }
  
  func hideSheet() {
    self.displaySheet = false
    self.sheetStyle = nil
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
    
    self.hasPreviousChapter = self.hasChapter(before: currentItem?.currentChapter)
    self.hasNextChapter = self.hasChapter(after: currentItem?.currentChapter)
    self.chapterBeforeSliderValueChange = currentItem?.currentChapter
    
    progressData.chapterTitle = currentItem?.currentChapter?.title
      ?? currentItem?.title
      ?? ""
    progressData.progress = progress
    progressData.maxTime = maxTimeInContext
    progressData.currentTime = currentTime
    progressData.sliderValue = Double(sliderValue)
  }

  func importTranscript(from url: URL) {
    guard let currentItem = playerManager.currentItem else {
      presentTranscriptImportError(BPTranscriptError.noBookLoaded)
      return
    }

    let canAccess = url.startAccessingSecurityScopedResource()
    defer {
      if canAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let contents = try String(contentsOf: url, encoding: .utf8)
      let lines = try LRCParser.parse(contents)
      try transcriptStore.saveTranscript(contents, for: currentItem.relativePath)
      transcriptLines = lines
      isShowingTranscript = true
      updateTranscriptPosition()
    } catch {
      presentTranscriptImportError(error)
    }
  }

  func presentTranscriptImportError(_ error: Error) {
    let message = error.localizedDescription
    currentAlert = BPAlertContent.errorAlert(title: "Transcript Import Failed", message: message)
  }

  func seekToTranscriptTime(_ time: TimeInterval) {
    playerManager.jumpTo(time, recordBookmark: true)
    updateTranscriptPosition()
  }

  private func resetTranscriptState() {
    transcriptLines = []
    activeTranscriptIndex = nil
    isShowingTranscript = false
  }

  private func loadTranscriptIfAvailable(for item: PlayableItem) {
    do {
      if let contents = try transcriptStore.loadTranscript(for: item.relativePath) {
        transcriptLines = try LRCParser.parse(contents)
      } else {
        transcriptLines = []
      }
    } catch {
      transcriptLines = []
    }

    activeTranscriptIndex = nil
    isShowingTranscript = false
  }

  private func updateTranscriptPosition() {
    guard !transcriptLines.isEmpty else {
      activeTranscriptIndex = nil
      return
    }

    let currentTime = playerManager.currentItem?.currentTime ?? 0
    let newIndex = transcriptIndex(for: currentTime)
    if newIndex != activeTranscriptIndex {
      activeTranscriptIndex = newIndex
    }
  }

  private func transcriptIndex(for time: TimeInterval) -> Int? {
    guard !transcriptLines.isEmpty else { return nil }

    if time < transcriptLines[0].time {
      return nil
    }

    var low = 0
    var high = transcriptLines.count - 1
    var result = 0

    while low <= high {
      let mid = (low + high) / 2
      if transcriptLines[mid].time <= time {
        result = mid
        low = mid + 1
      } else {
        high = mid - 1
      }
    }

    return result
  }
  
  func handleNextTap() {
    if let currentChapter = self.playerManager.currentItem?.currentChapter,
      let nextChapter = self.playerManager.currentItem?.nextChapter(after: currentChapter)
    {
      self.playerManager.jumpToChapter(nextChapter)
    } else {
      self.playerManager.playNextItem(autoPlayed: false, shouldAutoplay: true)
    }
    NotificationCenter.default.post(name: .listeningProgressChanged, object: nil)
  }
  
  func handlePreviousTap() {
    if let currentChapter = self.playerManager.currentItem?.currentChapter,
      let previousChapter = self.playerManager.currentItem?.previousChapter(before: currentChapter)
    {
      self.playerManager.jumpToChapter(previousChapter)
    } else {
      self.playerManager.playPreviousItem()
    }
    NotificationCenter.default.post(name: .listeningProgressChanged, object: nil)
  }
  
  func hasLoadedBook() -> Bool {
    return self.playerManager.hasLoadedBook()
  }
  
  func handleButtonTap(media: MediaAction) {
    switch media {
      case .bookmark:
        createBookmark()
      case .more:
        setMoreAlert()
      case .chapters:
        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks) {
          displaySheet(style: .bookmark)
        } else {
          displaySheet(style: .chapters)
        }
      case .speed:
        displaySheet(style: .controls)
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
          self?.displaySheet(style: .sleep)
        }
      )
    )

    actions.append(BPActionItem.cancelAction)

    let message: String
    switch SleepTimer.shared.state {
    case .off, .countdown:
      message = "player_sleep_title".localized
    case .endOfChapter:
      message = "sleep_alert_description".localized
    }

    currentAlertOrigin = .timer
    currentAlert = BPAlertContent(
      title: "",
      message: message,
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
  
  func handleAutolockStatus(forceDisable: Bool = false) {
    guard !forceDisable else {
      UIApplication.shared.isIdleTimerDisabled = false
      UIDevice.current.isBatteryMonitoringEnabled = false
      return
    }
    
    guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled) else {
      UIApplication.shared.isIdleTimerDisabled = false
      UIDevice.current.isBatteryMonitoringEnabled = false
      return
    }
    
    guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabledOnlyWhenPowered) else {
      UIApplication.shared.isIdleTimerDisabled = true
      UIDevice.current.isBatteryMonitoringEnabled = false
      return
    }
    
    if !UIDevice.current.isBatteryMonitoringEnabled {
      UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    UIApplication.shared.isIdleTimerDisabled = UIDevice.current.batteryState != .unplugged
  }
  
  func resetShowings() {
    hideSheet()
    isShowingNote = false
  }
  
  func showListFromMoreAction() {
    resetShowings()
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks) {
      displaySheet(style: .chapters)
    } else {
      displaySheet(style: .bookmark)
    }
  }
  
  func setMoreAlert() {
    guard self.hasLoadedBook() else { return }

    let markTitle = self.isBookFinished()
      ? "mark_unfinished_title".localized
      : "mark_finished_title".localized
    
    var actions = [BPActionItem]()

    actions.append(
      BPActionItem(
        title: self.getListTitleForMoreAction(),
        handler: { [weak self] in self?.showListFromMoreAction() }
      )
    )
    
    actions.append(
      BPActionItem(
        title: "jump_start_title".localized,
        handler: { [weak self] in self?.handleJumpToStart() }
      )
    )
    
    actions.append(
      BPActionItem(
        title: markTitle,
        handler: { [weak self] in self?.handleMarkCompletion() }
      )
    )
    
    actions.append(
      BPActionItem(
        title: "button_free_title".localized,
        handler: { [weak self] in self?.showButtonFree() }
      )
    )
    
    actions.append(
      BPActionItem(
        title: self.isRepeatEnabled()
          ? "repeat_turn_off_title".localized : "repeat_turn_on_title".localized,
        handler: { [weak self] in self?.handleEnableRepeat() }
      )
    )
    
    currentAlertOrigin = .more
    currentAlert = BPAlertContent(
      title: "",
      message: "",
      style: .actionSheet,
      actionItems: actions
    )
  }
  
  func showButtonFree() {
    displaySheet(style: .buttonFree)
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
          handler: { [weak self] in
            self?.lastBookmark = bookmark
            self?.resetShowings()
            self?.isShowingNote = true
          }
        )
      )
    }
    
    actions.append(
      BPActionItem(
        title: "bookmarks_see_title".localized,
        handler: { [weak self] in
          self?.displaySheet(style: .bookmark)
        }
      )
    )
    
    actions.append(
      BPActionItem(
        title: "ok_button".localized,
        style: .cancel,
        handler: { [weak self] in
          self?.currentAlert = nil
        }
      )
    )
    
    currentAlertOrigin = nil
    currentAlert = BPAlertContent(
      title: String.localizedStringWithFormat(titleKey.localized, formattedTime),
      message: "".localized,
      style: .alert,
      actionItems: actions
    )
  }
  
  func saveNote(note: String) {
    guard let myBookmark = lastBookmark else { return }
    
    self.libraryService.addNote(note, bookmark: myBookmark)
    self.syncService.scheduleSetBookmark(
      relativePath: myBookmark.relativePath,
      time: myBookmark.time,
      note: note
    )
    self.lastBookmark = nil
  }
}
