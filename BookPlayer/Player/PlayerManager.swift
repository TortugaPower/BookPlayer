//
//  PlayerManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/31/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import Combine
import Foundation
import MediaPlayer
import WidgetKit

// swiftlint:disable file_length

public protocol PlayerManagerProtocol: NSObjectProtocol {
  var currentItem: PlayableItem? { get set }
  var currentSpeed: Float { get set }
  var boostVolume: Bool { get set }
  var isPlaying: Bool { get }

  func load(_ item: PlayableItem, autoplay: Bool)
  func hasLoadedBook() -> Bool

  func playPreviousItem()
  func playNextItem(autoPlayed: Bool)
  func play()
  func playPause()
  func pause(fade: Bool)
  func stop()
  func rewind()
  func forward()
  func jumpTo(_ time: Double, recordBookmark: Bool)
  func jumpToChapter(_ chapter: PlayableChapter)
  func markAsCompleted(_ flag: Bool)
  func setSpeed(_ newValue: Float)

  func currentSpeedPublisher() -> Published<Float>.Publisher
  func isPlayingPublisher() -> AnyPublisher<Bool, Never>
  func currentItemPublisher() -> Published<PlayableItem?>.Publisher
}

final class PlayerManager: NSObject, PlayerManagerProtocol {
  private let libraryService: LibraryServiceProtocol
  private let playbackService: PlaybackServiceProtocol
  private let syncService: SyncServiceProtocol
  private let speedService: SpeedServiceProtocol
  private let socketService: SocketServiceProtocol
  private let userActivityManager: UserActivityManager

  private var audioPlayer = AVPlayer()

  private var fadeTimer: Timer?

  private var playableChapterSubscription: AnyCancellable?
  private var isPlayingSubscription: AnyCancellable?
  private var periodicTimeObserver: Any?
  /// Flag determining if it should resume playback after finishing up loading an item
  @Published private var playbackQueued: Bool?
  private var hasObserverRegistered = false
  private var observeStatus: Bool = false {
    didSet {
      guard oldValue != self.observeStatus else { return }

      if self.observeStatus {
        self.playerItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)
        self.hasObserverRegistered = true
      } else if self.hasObserverRegistered {
        self.playerItem?.removeObserver(self, forKeyPath: "status")
        self.hasObserverRegistered = false
      }
    }
  }

  private var playerItem: AVPlayerItem?
  private var loadChapterTask: Task<(), Never>?
  @Published var currentItem: PlayableItem?
  @Published var currentSpeed: Float = 1.0

  var nowPlayingInfo = [String: Any]()

  private let queue = OperationQueue()

  init(
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol,
    speedService: SpeedServiceProtocol,
    socketService: SocketServiceProtocol
  ) {
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.syncService = syncService
    self.speedService = speedService
    self.socketService = socketService
    self.userActivityManager = UserActivityManager(libraryService: libraryService)
    super.init()

    self.setupPlayerInstance()

    NotificationCenter.default.addObserver(self,
                                           selector: #selector(playerDidFinishPlaying(_:)),
                                           name: .AVPlayerItemDidPlayToEndTime,
                                           object: nil)
  }

  func setupPlayerInstance() {
    let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    self.periodicTimeObserver = self.audioPlayer.addPeriodicTimeObserver(
      forInterval: interval,
      queue: DispatchQueue.main
    ) { [weak self] _ in
      guard let self = self else { return }

      self.updateTime()
    }

    // Only route audio for AirPlay
    self.audioPlayer.allowsExternalPlayback = false
  }

  func currentItemPublisher() -> Published<PlayableItem?>.Publisher {
    return self.$currentItem
  }

  func hasLoadedBook() -> Bool {
    return playerItem != nil
  }

  func loadRemoteURLAsset(for chapter: PlayableChapter) async throws -> AVURLAsset {
    let fileURL = try await syncService
      .getRemoteFileURLs(of: chapter.relativePath, type: .book)[0].url
    let asset = AVURLAsset(url: fileURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])

    // TODO: Check if there's a way to reduce the time this operation takes
    // it's currently a bottleneck when streaming playback
    await asset.loadValues(forKeys: [
      "duration",
      "playable",
      "preferredRate",
      "preferredVolume",
      "hasProtectedContent",
      "providesPreciseDurationAndTiming",
      "commonMetadata",
      "metadata"
    ])

    guard !Task.isCancelled else {
      throw BookPlayerError.cancelledTask
    }

    /// Load artwork if it's not cached
    if !ArtworkService.isCached(relativePath: chapter.relativePath),
       let data = AVMetadataItem.metadataItems(
        from: asset.commonMetadata,
        filteredByIdentifier: .commonIdentifierArtwork
       ).first?.dataValue {
      ArtworkService.storeInCache(data, for: chapter.relativePath)
    }

    if currentItem?.isBoundBook == false {
      libraryService.loadChaptersIfNeeded(relativePath: chapter.relativePath, asset: asset)

      if let libraryItem = libraryService.getSimpleItem(with: chapter.relativePath),
         let playbackItem = try playbackService.getPlayableItem(from: libraryItem) {
        currentItem = playbackItem
      }
    }

    return asset
  }

  func loadPlayerItem(for chapter: PlayableChapter) async throws {
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(chapter.relativePath)

    let asset: AVURLAsset

    if syncService.isActive,
      !FileManager.default.fileExists(atPath: fileURL.path) {
      asset = try await loadRemoteURLAsset(for: chapter)
    } else {
      asset = AVURLAsset(url: fileURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    }

    // Clean just in case
    if self.hasObserverRegistered {
      self.playerItem?.removeObserver(self, forKeyPath: "status")
      self.hasObserverRegistered = false
    }

    self.playerItem = AVPlayerItem(asset: asset)
    self.playerItem?.audioTimePitchAlgorithm = .timeDomain
  }

  func load(_ item: PlayableItem, autoplay: Bool) {
    /// Cancel in case there's an ongoing load task
    loadChapterTask?.cancel()

    // Recover in case of failure
    if self.audioPlayer.status == .failed {
      if let observer = self.periodicTimeObserver {
        self.audioPlayer.removeTimeObserver(observer)
      }

      self.audioPlayer = AVPlayer()
      self.setupPlayerInstance()
    }

    // Preload item
    if self.currentItem != nil {
      stopPlayback()
    }

    self.currentItem = item

    self.playableChapterSubscription?.cancel()
    self.playableChapterSubscription = item.$currentChapter.sink { [weak self] chapter in
      guard let chapter = chapter else { return }

      self?.setNowPlayingBookTitle(chapter: chapter)
      NotificationCenter.default.post(name: .chapterChange, object: nil, userInfo: nil)
    }

    loadChapterMetadata(item.currentChapter, autoplay: autoplay)
  }

  func loadChapterMetadata(_ chapter: PlayableChapter, autoplay: Bool? = nil) {
    if let autoplay {
      playbackQueued = autoplay
    }

    loadChapterTask = Task { [unowned self] in
      do {
        try await self.loadPlayerItem(for: chapter)
        self.loadChapterOperation(chapter)
      } catch BookPlayerError.cancelledTask {
        /// Do nothing, as it was cancelled to load another item
      } catch {
        self.playbackQueued = nil
        self.observeStatus = false
        self.showErrorAlert(error.localizedDescription)
        return
      }
    }
  }

  func loadChapterOperation(_ chapter: PlayableChapter) {
    self.queue.addOperation {
      // try loading the player
      guard
        let playerItem = self.playerItem,
        chapter.duration > 0
      else {
        DispatchQueue.main.async {
          self.currentItem = nil
          NotificationCenter.default.post(name: .bookReady, object: nil, userInfo: ["loaded": false])
        }
        return
      }

      self.audioPlayer.replaceCurrentItem(with: nil)
      self.observeStatus = true
      self.audioPlayer.replaceCurrentItem(with: playerItem)

      // Update UI on main thread
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }

        self.currentSpeed = self.speedService.getSpeed(relativePath: chapter.relativePath)
        // Set book metadata for lockscreen and control center
        self.nowPlayingInfo = [
          MPNowPlayingInfoPropertyDefaultPlaybackRate: self.currentSpeed
        ]

        self.setNowPlayingBookTitle(chapter: chapter)
        self.setNowPlayingBookTime()

        ArtworkService.retrieveImageFromCache(for: chapter.relativePath) { result in
          let image: UIImage

          switch result {
          case .success(let value):
            image = value.image
          case .failure:
            image = ArtworkService.generateDefaultArtwork(from: ThemeManager.shared.currentTheme.linkColor)!
          }

          self.nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size,
                                                                               requestHandler: { (_) -> UIImage in
            image
          })

          MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo

        if let currentItem = self.currentItem {
          // if book is truly finished, start book again to avoid autoplaying next one
          // add 1 second as a finished threshold
          if currentItem.currentTime > 0.0 {
            let time = (currentItem.currentTime + 1) >= currentItem.duration ? 0 : currentItem.currentTime
            self.initializeChapterTime(time)
          }
        }

        NotificationCenter.default.post(name: .bookReady, object: nil, userInfo: ["loaded": true])
      }
    }
  }

  // Called every second by the timer
  func updateTime() {
    guard
      let currentItem,
      let playerItem,
      playerItem.status == .readyToPlay
    else {
      return
    }

    var currentTime = CMTimeGetSeconds(self.audioPlayer.currentTime())

    // When using devices with AirPlay 1,
    // `currentTime` can be negative when switching chapters
    if currentTime < 0 {
      currentTime = 0.05
    }

    if currentItem.isBoundBook {
      currentTime += currentItem.currentChapter.start
    } else if currentTime >= currentItem.currentChapter.end || currentTime < currentItem.currentChapter.start,
              let newChapter = currentItem.getChapter(at: currentTime) {
      currentItem.currentChapter = newChapter
    }

    updatePlaybackTime(item: currentItem, time: currentTime)

    self.userActivityManager.recordTime()

    self.setNowPlayingBookTime()

    MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo

    // stop timer if the book is finished
    if Int(currentTime) == Int(currentItem.duration) {
      // Once book a book is finished, ask for a review
      UserDefaults.standard.set(true, forKey: "ask_review")
    }

    NotificationCenter.default.post(name: .bookPlaying, object: nil, userInfo: nil)
  }

  // MARK: - Player states

  var isPlaying: Bool {
    return self.audioPlayer.timeControlStatus == .playing
  }

  func bindPauseObserver() {
    self.isPlayingSubscription?.cancel()
    self.isPlayingSubscription = self.audioPlayer.publisher(for: \.timeControlStatus)
      .delay(for: .seconds(0.1), scheduler: RunLoop.main, options: .none)
      .sink { timeControlStatus in
        if timeControlStatus == .paused {
          try? AVAudioSession.sharedInstance().setActive(false)
          self.isPlayingSubscription?.cancel()
        }
      }
  }

  func isPlayingPublisher() -> AnyPublisher<Bool, Never> {
    return Publishers.CombineLatest(
      audioPlayer.publisher(for: \.timeControlStatus),
      $playbackQueued
    )
    .map({ (timeControlStatus, playbackQueued) in
      return timeControlStatus == .playing || playbackQueued == true
    })
    .eraseToAnyPublisher()
  }

  var boostVolume: Bool = false {
    didSet {
      self.audioPlayer.volume = self.boostVolume
      ? Constants.Volume.boosted.rawValue
      : Constants.Volume.normal.rawValue
    }
  }

  static var rewindInterval: TimeInterval {
    get {
      if UserDefaults.standard.object(forKey: Constants.UserDefaults.rewindInterval.rawValue) == nil {
        return 30.0
      }

      return UserDefaults.standard.double(forKey: Constants.UserDefaults.rewindInterval.rawValue)
    }

    set {
      UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.rewindInterval.rawValue)

      MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [newValue] as [NSNumber]
    }
  }

  static var forwardInterval: TimeInterval {
    get {
      if UserDefaults.standard.object(forKey: Constants.UserDefaults.forwardInterval.rawValue) == nil {
        return 30.0
      }

      return UserDefaults.standard.double(forKey: Constants.UserDefaults.forwardInterval.rawValue)
    }

    set {
      UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.forwardInterval.rawValue)

      MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [newValue] as [NSNumber]
    }
  }

  func setNowPlayingBookTitle(chapter: PlayableChapter) {
    guard let currentItem = self.currentItem else { return }

    self.nowPlayingInfo[MPMediaItemPropertyTitle] = chapter.title
    self.nowPlayingInfo[MPMediaItemPropertyArtist] = currentItem.title
    self.nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = currentItem.author
  }

  func setNowPlayingBookTime() {
    guard let currentItem = self.currentItem else { return }

    let prefersChapterContext = UserDefaults.standard.bool(forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
    let prefersRemainingTime = UserDefaults.standard.bool(forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)
    let currentTimeInContext = currentItem.currentTimeInContext(prefersChapterContext)
    let maxTimeInContext = currentItem.maxTimeInContext(
      prefersChapterContext: prefersChapterContext,
      prefersRemainingTime: prefersRemainingTime,
      at: self.currentSpeed
    )

    // 1x is needed because of how the control center behaves when decrementing time
    self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
    self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTimeInContext

    let playbackDuration: TimeInterval
    let itemProgress: TimeInterval

    if prefersRemainingTime {
      playbackDuration = (abs(maxTimeInContext) + currentTimeInContext)

      let realMaxTime = currentItem.maxTimeInContext(
        prefersChapterContext: prefersChapterContext,
        prefersRemainingTime: false,
        at: self.currentSpeed
      )

      itemProgress = currentTimeInContext / realMaxTime
    } else {
      playbackDuration = maxTimeInContext
      itemProgress = currentTimeInContext / maxTimeInContext
    }

    self.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playbackDuration
    self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] = itemProgress

    socketService.sendEvent(
      .timeUpdate,
      payload: [
        "currentTime": currentItem.currentTime,
        "percentCompleted": currentItem.percentCompleted,
        "relativePath": currentItem.relativePath,
        "lastPlayDateTimestamp": Date().timeIntervalSince1970,
      ]
    )
  }
}

// MARK: - Seek Controls

extension PlayerManager {
  func jumpToChapter(_ chapter: PlayableChapter) {
    jumpTo(chapter.start + 0.5, recordBookmark: false)
  }

  func initializeChapterTime(_ time: Double) {
    guard let currentItem = self.currentItem else { return }

    let boundedTime = min(max(time, 0), currentItem.duration)

    updatePlaybackTime(item: currentItem, time: boundedTime)

    let newTime = currentItem.isBoundBook
    ? currentItem.getChapterTime(in: currentItem.currentChapter, for: boundedTime)
    : boundedTime
    self.audioPlayer.seek(to: CMTime(seconds: newTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
  }

  func jumpTo(_ time: Double, recordBookmark: Bool = true) {
    guard let currentItem = self.currentItem else { return }

    if recordBookmark {
      self.createOrUpdateAutomaticBookmark(
        at: currentItem.currentTime,
        relativePath: currentItem.relativePath,
        type: .skip
      )
    }

    let boundedTime = min(max(time, 0), currentItem.duration)

    let chapterBeforeSkip = currentItem.currentChapter
    updatePlaybackTime(item: currentItem, time: boundedTime)
    if let chapterAfterSkip = currentItem.getChapter(at: boundedTime),
       chapterBeforeSkip != chapterAfterSkip {
      currentItem.currentChapter = chapterAfterSkip
      // If chapters are different, and it's a bound book,
      // load the new chapter
      if currentItem.isBoundBook {
        loadChapterMetadata(chapterAfterSkip)
        return
      }
    }

    let newTime = currentItem.isBoundBook
    ? currentItem.getChapterTime(in: currentItem.currentChapter, for: boundedTime)
    : boundedTime
    self.audioPlayer.seek(to: CMTime(seconds: newTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
  }

  func forward() {
    guard let currentItem = self.currentItem else { return }

    let newTime = currentItem.getInterval(from: PlayerManager.forwardInterval) + currentItem.currentTime
    self.jumpTo(newTime)
  }

  func rewind() {
    guard let currentItem = self.currentItem else { return }

    let newTime = currentItem.getInterval(from: -PlayerManager.rewindInterval) + currentItem.currentTime
    self.jumpTo(newTime)
  }
}

// MARK: - Playback

extension PlayerManager {
  func play() {
    /// Ignore play commands if there's no item loaded
    guard let currentItem else { return }

    guard let playerItem else {
      /// Check if the playbable item is in the process of being set
      if observeStatus == false {
        load(currentItem, autoplay: true)
      }
      return
    }

    guard playerItem.status == .readyToPlay else {
      /// Try to reload the item if it failed to load previously
      if playerItem.status == .failed {
        load(currentItem, autoplay: true)
      } else {
        // queue playback
        self.playbackQueued = true
        self.observeStatus = true
      }

      return
    }

    self.userActivityManager.resumePlaybackActivity()

    self.libraryService.setLibraryLastBook(with: currentItem.relativePath)

    do {
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      fatalError("Failed to activate the audio session, \(error), description: \(error.localizedDescription)")
    }

    self.createOrUpdateAutomaticBookmark(
      at: currentItem.currentTime,
      relativePath: currentItem.relativePath,
      type: .play
    )

    // If book is completed, stop
    if Int(currentItem.duration) == Int(CMTimeGetSeconds(self.audioPlayer.currentTime())) { return }

    self.handleSmartRewind(currentItem)

    self.fadeTimer?.invalidate()
    self.boostVolume = UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)
    // Set play state on player and control center
    self.audioPlayer.playImmediately(atRate: self.currentSpeed)

    self.setNowPlayingBookTitle(chapter: currentItem.currentChapter)

    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .bookPlayed, object: nil, userInfo: ["book": currentItem])

      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  func handleSmartRewind(_ item: PlayableItem) {
    let smartRewindEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.smartRewindEnabled.rawValue)

    if smartRewindEnabled,
       let lastPlayTime = item.lastPlayDate {
      let timePassed = Date().timeIntervalSince(lastPlayTime)
      let timePassedLimited = min(max(timePassed, 0), Constants.SmartRewind.threshold.rawValue)

      let delta = timePassedLimited / Constants.SmartRewind.threshold.rawValue

      // Using a cubic curve to soften the rewind effect for lower values and strengthen it for higher
      let rewindTime = pow(delta, 3) * Constants.SmartRewind.maxTime.rawValue

      let newPlayerTime = max(CMTimeGetSeconds(self.audioPlayer.currentTime()) - rewindTime, 0)

      self.audioPlayer.seek(to: CMTime(seconds: newPlayerTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }
  }

  func setSpeed(_ newValue: Float) {
    self.speedService.setSpeed(newValue, relativePath: self.currentItem?.relativePath)
    self.currentSpeed = newValue
    if self.isPlaying {
      self.audioPlayer.rate = newValue
    }
  }

  // swiftlint:disable block_based_kvo
  // Using this instead of new form, because the new one wouldn't work properly on AVPlayerItem
  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
    guard let path = keyPath,
          path == "status",
          let item = object as? AVPlayerItem else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
          }

    guard item.status == .readyToPlay else {
      if item.status == .failed {
        playbackQueued = nil
        observeStatus = false
        showErrorAlert(item.error?.localizedDescription)
      }
      return
    }

    self.observeStatus = false

    if self.playbackQueued == true {
      self.play()
    } else {
      self.updateTime()
    }
    // Clean up flag
    self.playbackQueued = nil
  }

  func pause(fade: Bool) {
    guard let currentItem = self.currentItem else { return }

    self.observeStatus = false

    self.userActivityManager.stopPlaybackActivity()

    self.libraryService.setLibraryLastBook(with: currentItem.relativePath)

    let pauseActionBlock: () -> Void = { [weak self] in
      self?.bindPauseObserver()
      // Set pause state on player and control center
      self?.audioPlayer.pause()
      self?.playbackQueued = nil
      self?.loadChapterTask?.cancel()
      self?.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
      self?.setNowPlayingBookTime()
      MPNowPlayingInfoCenter.default().nowPlayingInfo = self?.nowPlayingInfo
    }

    NotificationCenter.default.post(name: .bookPaused, object: nil)

    guard fade else {
      pauseActionBlock()
      return
    }

    self.fadeTimer = self.audioPlayer.fadeVolume(from: 1, to: 0, duration: 5, completion: pauseActionBlock)
  }

  // Toggle play/pause of book
  func playPause() {
    // Pause player if it's playing
    if self.audioPlayer.timeControlStatus == .playing || playbackQueued == true {
      self.pause(fade: false)
    } else {
      self.play()
    }
  }

  func stop() {
    stopPlayback()

    self.libraryService.setLibraryLastBook(with: nil)

    self.currentItem = nil
  }

  private func stopPlayback() {
    observeStatus = false
    playbackQueued = nil

    audioPlayer.pause()
    loadChapterTask?.cancel()

    userActivityManager.stopPlaybackActivity()
  }

  func markAsCompleted(_ flag: Bool) {
    guard let currentItem = self.currentItem else { return }

    self.libraryService.markAsFinished(flag: true, relativePath: currentItem.relativePath)

    if let parentFolderPath = currentItem.parentFolder {
      libraryService.recursiveFolderProgressUpdate(from: parentFolderPath)
    }

    NotificationCenter.default.post(name: .bookEnd, object: nil, userInfo: nil)
  }

  func currentSpeedPublisher() -> Published<Float>.Publisher {
    return self.$currentSpeed
  }

  func playPreviousItem() {
    guard
      let currentItem = self.currentItem,
      let previousBook = self.playbackService.getPlayableItem(
        before: currentItem.relativePath,
        parentFolder: currentItem.parentFolder
      )
    else { return }

    load(previousBook, autoplay: true)
  }

  func playNextItem(autoPlayed: Bool = false) {
    /// If it's autoplayed, check if setting is enabled
    if autoPlayed,
       !UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled.rawValue) {
      return
    }

    let restartFinished = UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayRestartEnabled.rawValue)

    guard
      let currentItem = self.currentItem,
      let nextBook = self.playbackService.getPlayableItem(
        after: currentItem.relativePath,
        parentFolder: currentItem.parentFolder,
        autoplayed: autoPlayed,
        restartFinished: restartFinished
      )
    else { return }

    /// If autoplaying a finished book and restart is enabled, set currentTime to 0
    if autoPlayed,
       nextBook.isFinished,
       restartFinished {
      updatePlaybackTime(item: nextBook, time: 0)
    }

    load(nextBook, autoplay: true)
  }

  @objc
  func playerDidFinishPlaying(_ notification: Notification) {
    guard let currentItem = self.currentItem else { return }

    // Stop book/chapter change if the EOC sleep timer is active
    if SleepTimer.shared.isEndChapterActive() {
      NotificationCenter.default.post(name: .bookEnd, object: nil)
      return
    }

    if currentItem.chapters.last == currentItem.currentChapter {
      self.libraryService.setLibraryLastBook(with: nil)

      self.markAsCompleted(true)

      self.playNextItem(autoPlayed: true)
      return
    } else if currentItem.isBoundBook {
      updatePlaybackTime(item: currentItem, time: currentItem.currentTime)
      /// Load next chapter
      guard let nextChapter = self.playbackService.getNextChapter(from: currentItem) else { return }
      currentItem.currentChapter = nextChapter
      loadChapterMetadata(nextChapter, autoplay: true)
    }
  }

  /// Update the current item playback time, and checks for difference in progress percentage
  func updatePlaybackTime(item: PlayableItem, time: Float64) {
    let previousPercentage = Int(item.percentCompleted)
    self.playbackService.updatePlaybackTime(item: item, time: time)
    let newPercentage = Int(item.percentCompleted)

    if previousPercentage != newPercentage,
       let parentFolder = item.parentFolder {
      libraryService.recursiveFolderProgressUpdate(from: parentFolder)
    }
  }
}

// MARK: - BookMarks
extension PlayerManager {
  public func createOrUpdateAutomaticBookmark(at time: Double, relativePath: String, type: BookmarkType) {
    /// Clean up old bookmark
    if let bookmark = libraryService.getBookmarks(of: type, relativePath: relativePath)?.first {
      libraryService.deleteBookmark(bookmark)
    }

    guard
      let bookmark = libraryService.createBookmark(at: floor(time), relativePath: relativePath, type: type)
    else { return }

    libraryService.addNote(type.getNote() ?? "", bookmark: bookmark)
  }
}

extension PlayerManager {
  private func showErrorAlert(_ message: String?) {
    DispatchQueue.main.async {
      SceneDelegate.shared?.coordinator.getMainCoordinator()?
        .getTopController()?
        .showAlert("error_title".localized, message: message)
    }
  }
}
