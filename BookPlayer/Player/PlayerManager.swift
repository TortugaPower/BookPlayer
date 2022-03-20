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
  var boostVolume: Bool { get set }

  func load(_ item: PlayableItem)
  func hasLoadedBook() -> Bool

  func playItem(_ item: PlayableItem)
  func playPreviousItem()
  func playNextItem(autoPlayed: Bool)
  func play()
  func playPause()
  func pause(fade: Bool)
  func stop()
  func rewind()
  func forward()
  func jumpTo(_ time: Double, recordBookmark: Bool)
  func markAsCompleted(_ flag: Bool)

  func getCurrentSpeed() -> Float
  func currentSpeedPublisher() -> AnyPublisher<Float, Never>

  func isPlayingPublisher() -> AnyPublisher<Bool, Never>
  func currentItemPublisher() -> Published<PlayableItem?>.Publisher
}

final class PlayerManager: NSObject, PlayerManagerProtocol {
  private let libraryService: LibraryServiceProtocol
  private let playbackService: PlaybackServiceProtocol
  private let speedManager: SpeedManager
  private let userActivityManager: UserActivityManager

  private var audioPlayer = AVPlayer()

  private var fadeTimer: Timer?

  private var playableChapterSubscription: AnyCancellable?
  private var speedSubscription: AnyCancellable?
  private var periodicTimeObserver: Any?

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
  @Published var currentItem: PlayableItem?

  private var nowPlayingInfo = [String: Any]()

  private let queue = OperationQueue()

  init(libraryService: LibraryServiceProtocol,
       playbackService: PlaybackServiceProtocol,
       speedManager: SpeedManager) {
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.speedManager = speedManager
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
    return self.audioPlayer.currentItem != nil
  }

  func loadPlayerItem(for chapter: PlayableChapter) {
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(chapter.relativePath)

    let bookAsset = AVURLAsset(url: fileURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])

    // Clean just in case
    if self.hasObserverRegistered {
      self.playerItem?.removeObserver(self, forKeyPath: "status")
      self.hasObserverRegistered = false
    }

    self.playerItem = AVPlayerItem(asset: bookAsset)
    self.playerItem?.audioTimePitchAlgorithm = .timeDomain
  }

  func load(_ item: PlayableItem) {
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
      self.stop()
    }

    self.currentItem = item

    self.playableChapterSubscription?.cancel()
    self.playableChapterSubscription = item.$currentChapter.sink { [weak self] chapter in
      guard let chapter = chapter else { return }

      self?.setNowPlayingBookTitle(chapter: chapter)
      NotificationCenter.default.post(name: .chapterChange, object: nil, userInfo: nil)

      // avoid loading the same item if it's already loaded
      if let playingURL = (self?.audioPlayer.currentItem?.asset as? AVURLAsset)?.url,
         chapter.fileURL == playingURL {
        return
      }

      self?.loadChapter(chapter)
    }
  }

  func loadChapter(_ chapter: PlayableChapter) {
    self.loadPlayerItem(for: chapter)

    self.queue.addOperation {
      // try loading the player
      guard let playerItem = self.playerItem,
            chapter.duration > 0 else {
              DispatchQueue.main.async {
                self.currentItem = nil

                NotificationCenter.default.post(name: .bookReady, object: nil, userInfo: ["loaded": false])
              }

              return
            }

      self.audioPlayer.replaceCurrentItem(with: nil)
      self.audioPlayer.replaceCurrentItem(with: playerItem)

      // Update UI on main thread
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        // Set book metadata for lockscreen and control center
        self.nowPlayingInfo = [
          MPNowPlayingInfoPropertyDefaultPlaybackRate: self.speedManager.getSpeed(relativePath: chapter.relativePath)
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
            self.jumpTo(time, recordBookmark: false)
          }

          self.libraryService.updateBookLastPlayDate(at: currentItem.relativePath, date: Date())
        }

        NotificationCenter.default.post(name: .bookReady, object: nil, userInfo: ["loaded": true])
      }
    }
  }

  // Called every second by the timer
  func updateTime(includeItem: Bool = false) {
    guard let currentItem = self.currentItem,
          let playerItem = self.playerItem,
          playerItem.status == .readyToPlay else {
            return
          }

    var currentTime = CMTimeGetSeconds(self.audioPlayer.currentTime())

    // When using devices with AirPlay 1,
    // `currentTime` can be negative when switching chapters
    if currentTime < 0 {
      currentTime = 0.05
    }

    if currentItem.useChapterTimeContext {
      currentTime += currentItem.currentChapter.start
    }

    self.playbackService.updatePlaybackTime(item: currentItem, time: currentTime)

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

  private func bindSpeedObserver() {
    self.speedSubscription?.cancel()
    self.speedSubscription = self.speedManager.currentSpeed
      .removeDuplicates()
      .sink { [weak self] speed in
      guard let self = self,
            self.isPlaying else { return }

      self.audioPlayer.rate = speed
    }
  }

  // MARK: - Player states

  var isPlaying: Bool {
    return self.audioPlayer.timeControlStatus == .playing
  }

  func isPlayingPublisher() -> AnyPublisher<Bool, Never> {
    return self.audioPlayer.publisher(for: \.timeControlStatus)
      .map({ timeControlStatus in
        return timeControlStatus == .playing
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
      at: self.getCurrentSpeed()
    )

    // 1x is needed because of how the control center behaves when decrementing time
    self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
    self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTimeInContext
    self.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = prefersRemainingTime
    ? (abs(maxTimeInContext) + currentTimeInContext)
    : maxTimeInContext
    self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] = currentTimeInContext / maxTimeInContext
  }
}

// MARK: - Seek Controls

extension PlayerManager {
  func jumpTo(_ time: Double, recordBookmark: Bool = true) {
    guard let currentItem = self.currentItem else { return }

    if recordBookmark {
      self.createOrUpdateAutomaticBookmark(
        at: currentItem.currentTime,
        relativePath: currentItem.relativePath,
        type: .skip
      )
    }

    if !self.isPlaying {
      UserDefaults.standard.set(Date(), forKey: "\(Constants.UserDefaults.lastPauseTime)_\(currentItem.relativePath)")
    }

    let boundedTime = min(max(time, 0), currentItem.duration)

    let chapterBeforeSkip = currentItem.currentChapter
    self.playbackService.updatePlaybackTime(item: currentItem, time: boundedTime)
    NotificationCenter.default.post(name: .bookPlaying, object: nil, userInfo: nil)
    let chapterAfterSkip = currentItem.currentChapter

    // If chapters are different, and time is considered by chapters, do nothing else
    if chapterBeforeSkip != chapterAfterSkip,
       currentItem.useChapterTimeContext {
      return
    }

    let newTime = currentItem.useChapterTimeContext
    ? currentItem.getChapterTime(from: boundedTime)
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
    guard let currentItem = self.currentItem,
          let playerItem = self.playerItem else { return }

    guard playerItem.status == .readyToPlay else {
      // queue playback
      self.observeStatus = true
      return
    }

    self.userActivityManager.resumePlaybackActivity()

    self.libraryService.setLibraryLastBook(with: currentItem.relativePath)

    do {
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      fatalError("Failed to activate the audio session")
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
    self.audioPlayer.playImmediately(atRate: self.speedManager.getSpeed(relativePath: currentItem.relativePath))
    self.bindSpeedObserver()

    // Set last Play date
    self.libraryService.updateBookLastPlayDate(at: currentItem.relativePath, date: Date())

    self.setNowPlayingBookTitle(chapter: currentItem.currentChapter)

    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .bookPlayed, object: nil, userInfo: ["book": currentItem])
      if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadAllTimelines()
      }
    }
  }

  func handleSmartRewind(_ item: PlayableItem) {
    // Handle smart rewind.
    let lastPauseTimeKey = "\(Constants.UserDefaults.lastPauseTime)_\(item.relativePath)"
    let smartRewindEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.smartRewindEnabled.rawValue)

    if smartRewindEnabled, let lastPlayTime: Date = UserDefaults.standard.object(forKey: lastPauseTimeKey) as? Date {
      let timePassed = Date().timeIntervalSince(lastPlayTime)
      let timePassedLimited = min(max(timePassed, 0), Constants.SmartRewind.threshold.rawValue)

      let delta = timePassedLimited / Constants.SmartRewind.threshold.rawValue

      // Using a cubic curve to soften the rewind effect for lower values and strengthen it for higher
      let rewindTime = pow(delta, 3) * Constants.SmartRewind.maxTime.rawValue

      let newPlayerTime = max(CMTimeGetSeconds(self.audioPlayer.currentTime()) - rewindTime, 0)

      UserDefaults.standard.set(nil, forKey: lastPauseTimeKey)

      self.audioPlayer.seek(to: CMTime(seconds: newPlayerTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
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
        AppDelegate.delegateInstance.topController?.showAlert("error_title".localized, message: item.error?.localizedDescription)
      }
      return
    }

    self.observeStatus = false

    self.play()
  }

  func pause(fade: Bool) {
    guard let currentItem = self.currentItem else { return }

    self.observeStatus = false

    self.userActivityManager.stopPlaybackActivity()

    self.libraryService.setLibraryLastBook(with: currentItem.relativePath)

    let pauseActionBlock: () -> Void = {
      // Set pause state on player and control center
      self.audioPlayer.pause()
      self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
      self.setNowPlayingBookTime()
      MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo

      UserDefaults.standard.set(Date(), forKey: "\(Constants.UserDefaults.lastPauseTime)_\(currentItem.relativePath)")

      try? AVAudioSession.sharedInstance().setActive(false)
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
    if self.audioPlayer.timeControlStatus == .playing {
      self.pause(fade: false)
    } else {
      self.play()
    }
  }

  func stop() {
    self.observeStatus = false

    self.audioPlayer.pause()

    self.userActivityManager.stopPlaybackActivity()

    self.libraryService.setLibraryLastBook(with: nil)

    self.currentItem = nil
  }

  func markAsCompleted(_ flag: Bool) {
    guard let currentItem = self.currentItem else { return }

    self.libraryService.markAsFinished(flag: true, relativePath: currentItem.relativePath)

    NotificationCenter.default.post(name: .bookEnd, object: nil, userInfo: nil)
  }

  func getCurrentSpeed() -> Float {
    return self.speedManager.getSpeed(relativePath: self.currentItem?.relativePath)
  }

  func currentSpeedPublisher() -> AnyPublisher<Float, Never> {
    return self.speedManager.currentSpeedPublisher()
  }

  func playPreviousItem() {
    guard let currentItem = self.currentItem,
          let previousBook = self.playbackService.getPlayableItem(before: currentItem.relativePath) else { return }

    self.playItem(previousBook)
  }

  func playNextItem(autoPlayed: Bool = false) {
    guard
      let currentItem = self.currentItem,
      let nextBook = self.playbackService.getPlayableItem(after: currentItem.relativePath, autoplayed: autoPlayed)
    else { return }

    self.playItem(nextBook)
  }

  func playItem(_ item: PlayableItem) {
    var subscription: AnyCancellable?

    subscription = NotificationCenter.default.publisher(for: .bookReady, object: nil)
      .sink(receiveValue: { [weak self] notification in
        guard let self = self,
              let userInfo = notification.userInfo,
              let loaded = userInfo["loaded"] as? Bool,
              loaded == true else {
                subscription?.cancel()
                return
              }

        // Resume playback if it's paused
        if !self.isPlaying {
          self.play()
        }

        subscription?.cancel()
      })

    self.load(item)
  }

  @objc
  func playerDidFinishPlaying(_ notification: Notification) {
    guard let currentItem = self.currentItem else { return }

    // Clear out smart rewind key from finished item
    let lastPauseTimeKey = "\(Constants.UserDefaults.lastPauseTime)_\(currentItem.relativePath)"
    UserDefaults.standard.set(nil, forKey: lastPauseTimeKey)

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
    } else {
      if currentItem.useChapterTimeContext {
        var subscription: AnyCancellable?

        subscription = NotificationCenter.default.publisher(for: .bookReady, object: nil)
          .sink(receiveValue: { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let loaded = userInfo["loaded"] as? Bool,
                  loaded == true else {
                    subscription?.cancel()
                    return
                  }

            self.play()

            subscription?.cancel()
          })

        self.playbackService.updatePlaybackTime(item: currentItem, time: currentItem.currentTime + 0.5)
      }
    }
  }
}

// MARK: - BookMarks
extension PlayerManager {
  public func createOrUpdateAutomaticBookmark(at time: Double, relativePath: String, type: BookmarkType) {
    let bookmark = self.libraryService.getBookmarks(of: type, relativePath: relativePath)?.first
    ?? self.libraryService.createBookmark(at: time, relativePath: relativePath, type: type)
    bookmark.time = floor(time)

    self.libraryService.addNote(type.getNote() ?? "", bookmark: bookmark)
  }
}
