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

// swiftlint:disable:next file_length
/// sourcery: AutoMockable
public protocol PlayerManagerProtocol {
  var currentItem: PlayableItem? { get set }
  var currentSpeed: Float { get set }
  var isPlaying: Bool { get }

  func load(_ item: PlayableItem, autoplay: Bool)
  func hasLoadedBook() -> Bool

  func playPreviousItem()
  func playNextItem(autoPlayed: Bool, shouldAutoplay: Bool)
  func play()
  func playPause()
  func pause()
  func stop()
  func rewind()
  func forward()
  func jumpTo(_ time: Double, recordBookmark: Bool)
  func jumpToChapter(_ chapter: PlayableChapter)
  func markAsCompleted(_ flag: Bool)
  func setSpeed(_ newValue: Float)
  func setBoostVolume(_ newValue: Bool)

  func currentSpeedPublisher() -> AnyPublisher<Float, Never>
  func isPlayingPublisher() -> AnyPublisher<Bool, Never>
  func currentItemPublisher() -> AnyPublisher<PlayableItem?, Never>
}

final class PlayerManager: NSObject, PlayerManagerProtocol {
  private let libraryService: LibraryServiceProtocol
  private let playbackService: PlaybackServiceProtocol
  private let syncService: SyncServiceProtocol
  private let speedService: SpeedServiceProtocol
  private let userActivityManager: UserActivityManager
  private let shakeMotionService: ShakeMotionServiceProtocol
  private let widgetReloadService: WidgetReloadServiceProtocol

  private var audioPlayer = AVPlayer()

  private var fadeTimer: Timer?

  private var timeControlPassthroughPublisher = CurrentValueSubject<AVPlayer.TimeControlStatus, Never>(.paused)
  private var timeControlSubscription: AnyCancellable?
  private var playableChapterSubscription: AnyCancellable?
  private var isPlayingSubscription: AnyCancellable?
  private var periodicTimeObserver: Any?
  private var disposeBag = Set<AnyCancellable>()
  /// Flag determining if it should resume playback after finishing up loading an item
  @Published private var playbackQueued: Bool?
  /// Flag determining if it's in the process of fetching the URL for playback
  @Published private var isFetchingRemoteURL: Bool?
  /// Prevent loop from automatic URL refreshes
  private var canFetchRemoteURL = true
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
    shakeMotionService: ShakeMotionServiceProtocol,
    widgetReloadService: WidgetReloadServiceProtocol
  ) {
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.syncService = syncService
    self.speedService = speedService
    self.userActivityManager = UserActivityManager(libraryService: libraryService)
    self.shakeMotionService = shakeMotionService
    self.widgetReloadService = widgetReloadService
    super.init()

    setupPlayerInstance()
    bindObservers()
  }

  func bindObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(playerDidFinishPlaying(_:)),
      name: .AVPlayerItemDidPlayToEndTime,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleMediaServicesWereReset),
      name: AVAudioSession.mediaServicesWereResetNotification,
      object: nil
    )

    SleepTimer.shared.countDownThresholdPublisher.sink { [weak self] _ in
      self?.handleSleepTimerThresholdEvent()
    }.store(in: &disposeBag)

    SleepTimer.shared.timerEndedPublisher.sink { [weak self] state in
      self?.handleSleepTimerEndEvent(state)
    }.store(in: &disposeBag)
  }

  func bindInterruptObserver() {
    NotificationCenter.default.removeObserver(
      self,
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.handleAudioInterruptions(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
  }

  func setupPlayerInstance() {
    if let observer = periodicTimeObserver {
      audioPlayer.removeTimeObserver(observer)
    }

    audioPlayer = AVPlayer()

    let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    periodicTimeObserver = audioPlayer.addPeriodicTimeObserver(
      forInterval: interval,
      queue: DispatchQueue.main
    ) { [weak self] _ in
      guard let self = self else { return }

      self.updateTime()
    }

    // Only route audio for AirPlay
    audioPlayer.allowsExternalPlayback = false

    bindTimeControlPassthroughPublisher()
  }

  func currentItemPublisher() -> AnyPublisher<PlayableItem?, Never> {
    return self.$currentItem.eraseToAnyPublisher()
  }

  func hasLoadedBook() -> Bool {
    if playerItem == nil {
      return currentItem != nil
    } else {
      return true
    }
  }

  func loadRemoteURLAsset(for chapter: PlayableChapter, forceRefresh: Bool) async throws -> AVURLAsset {
    let fileURL: URL

    if !forceRefresh,
       let chapterURL = chapter.remoteURL {
      fileURL = chapterURL
    } else {
      isFetchingRemoteURL = true
      fileURL = try await syncService
        .getRemoteFileURLs(of: chapter.relativePath, type: .book)[0].url
      isFetchingRemoteURL = false
    }

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
      await ArtworkService.storeInCache(data, for: chapter.relativePath)
    }

    if currentItem?.isBoundBook == false {
      libraryService.loadChaptersIfNeeded(relativePath: chapter.relativePath, asset: asset)

      if let libraryItem = libraryService.getSimpleItem(with: chapter.relativePath) {
        currentItem = try playbackService.getPlayableItem(from: libraryItem)
      }
    }

    return asset
  }

  func loadPlayerItem(for chapter: PlayableChapter, forceRefreshURL: Bool) async throws {
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(chapter.relativePath)

    let asset: AVURLAsset

    if syncService.isActive,
       !FileManager.default.fileExists(atPath: fileURL.path) {
      asset = try await loadRemoteURLAsset(for: chapter, forceRefresh: forceRefreshURL)
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
    load(item, autoplay: autoplay, forceRefreshURL: false)
  }

  private func load(_ item: PlayableItem, autoplay: Bool, forceRefreshURL: Bool) {
    /// Cancel in case there's an ongoing load task
    loadChapterTask?.cancel()

    // Recover in case of failure
    if audioPlayer.status == .failed {
      setupPlayerInstance()
    }

    // Preload item
    if self.currentItem != nil {
      stopPlayback()
      playerItem = nil
      /// Clear out flag when `playerItem` is nulled out
      hasObserverRegistered = false
      currentItem = nil
    }

    self.currentItem = item

    self.playableChapterSubscription?.cancel()
    self.playableChapterSubscription = item.$currentChapter.sink { [weak self] chapter in
      guard let chapter = chapter else { return }

      self?.setNowPlayingBookTitle(chapter: chapter)
      NotificationCenter.default.post(name: .chapterChange, object: nil, userInfo: nil)
      self?.widgetReloadService.scheduleWidgetReload(of: .sharedNowPlayingWidget)
    }

    loadChapterMetadata(item.currentChapter, autoplay: autoplay, forceRefreshURL: forceRefreshURL)
  }

  func loadChapterMetadata(_ chapter: PlayableChapter, autoplay: Bool? = nil, forceRefreshURL: Bool = false) {
    if let autoplay {
      playbackQueued = autoplay
    }

    loadChapterTask = Task { [unowned self] in
      do {
        try await self.loadPlayerItem(for: chapter, forceRefreshURL: forceRefreshURL)
        self.loadChapterOperation(chapter)
      } catch BookPlayerError.cancelledTask {
        /// Do nothing, as it was cancelled to load another item
      } catch {
        self.playbackQueued = nil
        self.isFetchingRemoteURL = nil
        self.observeStatus = false
        self.showErrorAlert(title: "\("error_title".localized) Metadata", error.localizedDescription)
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
        DispatchQueue.main.async { [weak self] in
          self?.playbackQueued = nil
          self?.isFetchingRemoteURL = nil
          NotificationCenter.default.post(name: .bookReady, object: nil, userInfo: ["loaded": false])
        }
        return
      }

      self.audioPlayer.replaceCurrentItem(with: nil)
      self.observeStatus = true
      self.isFetchingRemoteURL = nil
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
        self.setNowPlayingArtwork(chapter: chapter)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
        MPNowPlayingInfoCenter.default().playbackState = .playing

        if let currentItem = self.currentItem {
          // if book is truly finished, start book again to avoid autoplaying next one
          // add 1 second as a finished threshold
          if currentItem.currentTime > 0.0 {
            let time = (currentItem.currentTime + 1) >= currentItem.duration ? 0 : currentItem.currentTime
            self.initializeChapterTime(time)
          }
        }

        NotificationCenter.default.post(name: .bookReady, object: nil, userInfo: ["loaded": true])
        self.widgetReloadService.reloadAllWidgets()
      }
    }
  }

  func setNowPlayingArtwork(chapter: PlayableChapter) {
    var pathForArtwork = chapter.relativePath

    if !ArtworkService.isCached(relativePath: chapter.relativePath),
       let currentItem = currentItem {
      pathForArtwork = currentItem.relativePath
    }

    ArtworkService.retrieveImageFromCache(for: pathForArtwork) { [weak self] result in
      guard let self else { return }

      let image: UIImage

      switch result {
      case .success(let value):
        image = value.image
      case .failure:
        image = ArtworkService.generateDefaultArtwork(from: ThemeManager.shared.currentTheme.linkColor)!
      }

      self.nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
        boundsSize: image.size,
        requestHandler: { (_) -> UIImage in
          image
        })

      MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
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

  /// We need an intermediate publisher for the `timeControlStatus`, as the `AVPlayer` instance can be recreated,
  /// thus invalidating the registered observers for `isPlaying`
  func bindTimeControlPassthroughPublisher() {
    timeControlSubscription?.cancel()
    timeControlSubscription = audioPlayer.publisher(for: \.timeControlStatus)
      .sink { [weak self] timeControlStatus in
        self?.timeControlPassthroughPublisher.send(timeControlStatus)
      }
  }

  func bindPauseObserver() {
    self.isPlayingSubscription?.cancel()
    self.isPlayingSubscription = timeControlPassthroughPublisher
      .delay(for: .seconds(0.1), scheduler: RunLoop.main, options: .none)
      .sink { timeControlStatus in
        if timeControlStatus == .paused {
          try? AVAudioSession.sharedInstance().setActive(false)
          self.isPlayingSubscription?.cancel()
        }
      }
  }

  func isPlayingPublisher() -> AnyPublisher<Bool, Never> {
    return Publishers.CombineLatest3(
      timeControlPassthroughPublisher,
      $playbackQueued,
      $isFetchingRemoteURL
    )
    .map({ (timeControlStatus, playbackQueued, isFetchingRemoteURL) -> Bool in
      let controlStatusFlag = timeControlStatus != .paused
      let playbackQueuedFlag = playbackQueued == true
      return controlStatusFlag
      || playbackQueuedFlag
      || (isFetchingRemoteURL == true && playbackQueuedFlag)
    })
    .eraseToAnyPublisher()
  }

  var boostVolume: Bool = false {
    didSet {
      self.audioPlayer.volume = self.boostVolume
      ? Constants.Volume.boosted
      : Constants.Volume.normal
    }
  }

  static var rewindInterval: TimeInterval {
    get {
      if UserDefaults.standard.object(forKey: Constants.UserDefaults.rewindInterval) == nil {
        return 30.0
      }

      return UserDefaults.standard.double(forKey: Constants.UserDefaults.rewindInterval)
    }

    set {
      UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.rewindInterval)

      MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [newValue] as [NSNumber]
    }
  }

  static var forwardInterval: TimeInterval {
    get {
      if UserDefaults.standard.object(forKey: Constants.UserDefaults.forwardInterval) == nil {
        return 30.0
      }

      return UserDefaults.standard.double(forKey: Constants.UserDefaults.forwardInterval)
    }

    set {
      UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.forwardInterval)

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

    let prefersChapterContext = UserDefaults.sharedDefaults.bool(
      forKey: Constants.UserDefaults.chapterContextEnabled
    )
    let prefersRemainingTime = UserDefaults.sharedDefaults.bool(
      forKey: Constants.UserDefaults.remainingTimeEnabled
    )
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

    /// Allow refetching remote URL if the action was initiating by the user
    canFetchRemoteURL = true

    guard let playerItem else {
      /// Check if the playbable item is in the process of being set
      if observeStatus == false {
        if isFetchingRemoteURL == true {
          playbackQueued = true
        } else {
          load(currentItem, autoplay: true)
        }
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
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(
        AVAudioSession.Category.playback,
        mode: .spokenAudio,
        options: []
      )
      try audioSession.setActive(true)
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
    self.shakeMotionService.stopMotionUpdates()
    self.boostVolume = UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled)
    bindInterruptObserver()
    // Set play state on player and control center
    self.audioPlayer.playImmediately(atRate: self.currentSpeed)

    self.setNowPlayingBookTitle(chapter: currentItem.currentChapter)

    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .bookPlayed, object: nil, userInfo: ["book": currentItem])
    }
  }

  func handleSmartRewind(_ item: PlayableItem) {
    let smartRewindEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.smartRewindEnabled)

    if smartRewindEnabled,
       let lastPlayTime = item.lastPlayDate {
      let timePassed = Date().timeIntervalSince(lastPlayTime)
      let timePassedLimited = min(max(timePassed, 0), Constants.SmartRewind.threshold)

      let delta = timePassedLimited / Constants.SmartRewind.threshold

      // Using a cubic curve to soften the rewind effect for lower values and strengthen it for higher
      let rewindTime = pow(delta, 3) * Constants.SmartRewind.maxTime

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

  func setBoostVolume(_ newValue: Bool) {
    self.boostVolume = newValue
  }

  // swiftlint:disable block_based_kvo
  // Using this instead of new form, because the new one wouldn't work properly on AVPlayerItem
  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
    guard 
      let path = keyPath,
      path == "status",
      let item = object as? AVPlayerItem
    else {
      super.observeValue(
        forKeyPath: keyPath,
        of: object,
        change: change,
        context: context
      )
      return
    }

    switch item.status {
    case .readyToPlay:
      self.observeStatus = false

      if self.playbackQueued == true {
        self.play()
      }
      // Clean up flag
      self.playbackQueued = nil
    case .failed:
      if canFetchRemoteURL,
        (item.error as? NSError)?.code == NSURLErrorResourceUnavailable,
        let currentItem {
        loadAndRefreshURL(item: currentItem)
        canFetchRemoteURL = false
      } else {
        playbackQueued = nil
        observeStatus = false
        playerItem = nil
        showErrorAlert(title: "\("error_title".localized) AVPlayerItem", item.error?.localizedDescription)
      }
    case .unknown:
      /// Do not handle .unknown states, as we're only interested in the success and failure states
      fallthrough
    @unknown default:
      break
    }
  }
  // swiftlint:enable block_based_kvo

  func pause() {
    pause(removeInterruptObserver: true)
  }

  func pause(removeInterruptObserver: Bool) {
    guard let currentItem = self.currentItem else { return }

    self.observeStatus = false

    self.userActivityManager.stopPlaybackActivity()

    self.libraryService.setLibraryLastBook(with: currentItem.relativePath)

    NotificationCenter.default.post(name: .bookPaused, object: nil)

    bindPauseObserver()
    // Set pause state on player and control center
    audioPlayer.pause()
    playbackQueued = nil
    loadChapterTask?.cancel()
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
    MPNowPlayingInfoCenter.default().playbackState = .paused
    setNowPlayingBookTime()
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    if removeInterruptObserver {
      NotificationCenter.default.removeObserver(
        self,
        name: AVAudioSession.interruptionNotification,
        object: nil
      )
    }
  }

  // Toggle play/pause of book
  func playPause() {
    // Pause player if it's playing
    if self.audioPlayer.timeControlStatus == .playing || playbackQueued == true {
      self.pause()
    } else {
      self.play()
    }
  }

  func stop() {
    stopPlayback()

    self.currentItem = nil
    playerItem = nil
    /// Clear out flag when `playerItem` is nulled out
    hasObserverRegistered = false
    MPNowPlayingInfoCenter.default().playbackState = .stopped
  }

  private func stopPlayback() {
    observeStatus = false
    playbackQueued = nil

    audioPlayer.pause()
    loadChapterTask?.cancel()

    userActivityManager.stopPlaybackActivity()
    NotificationCenter.default.removeObserver(
      self,
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
  }

  func markAsCompleted(_ flag: Bool) {
    guard let currentItem = self.currentItem else { return }

    self.libraryService.markAsFinished(flag: flag, relativePath: currentItem.relativePath)

    if let parentFolderPath = currentItem.parentFolder {
      if UIApplication.shared.applicationState == .active {
        libraryService.recursiveFolderProgressUpdate(from: parentFolderPath)
      } else {
        /// Defer all the folder progress updates until the user opens up the app again
        playbackService.markStaleProgress(folderPath: parentFolderPath)
      }
    }

    currentItem.isFinished = flag

    NotificationCenter.default.post(name: .bookEnd, object: nil, userInfo: nil)
  }

  func currentSpeedPublisher() -> AnyPublisher<Float, Never> {
    return $currentSpeed.eraseToAnyPublisher()
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

  func playNextItem(autoPlayed: Bool = false, shouldAutoplay: Bool = true) {
    /// If it's autoplayed, check if setting is enabled
    if autoPlayed,
       !UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled) {
      return
    }

    let restartFinished = UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayRestartEnabled)

    guard
      let currentItem = self.currentItem,
      let nextBook = getNextPlayableBook(
        after: currentItem,
        autoPlayed: autoPlayed,
        restartFinished: restartFinished
      )
    else { return }

    /// If autoplaying a finished book and restart is enabled, set currentTime to 0
    if autoPlayed,
       nextBook.isFinished,
       restartFinished {
      updatePlaybackTime(item: nextBook, time: 0)
    }

    load(nextBook, autoplay: shouldAutoplay)
  }

  /// Check `UTType` of the book before returning it
  /// Note: if the type does not conform to `.audiovisualContent` it will skip the item
  func getNextPlayableBook(
    after item: PlayableItem,
    autoPlayed: Bool,
    restartFinished: Bool
  ) -> PlayableItem? {
    guard
      let nextBook = self.playbackService.getPlayableItem(
        after: item.relativePath,
        parentFolder: item.parentFolder,
        autoplayed: autoPlayed,
        restartFinished: restartFinished
      )
    else { return nil }

    let fileExtension = nextBook.fileURL.pathExtension

    /// Only check for audiovisual content if a file extension is present
    if !fileExtension.isEmpty,
       let fileType = UTType(filenameExtension: fileExtension),
       !fileType.isSubtype(of: .audiovisualContent) {
      return getNextPlayableBook(
        after: nextBook,
        autoPlayed: autoPlayed,
        restartFinished: restartFinished
      )
    }

    return nextBook
  }

  /// Check `UTType` of the chapter before returning it
  /// Note: if the type does not conform to `.audiovisualContent` it will skip the item
  func getNextPlayableChapter(
    currentItem: PlayableItem,
    after chapter: PlayableChapter
  ) -> PlayableChapter? {
    guard let nextChapter = self.playbackService.getNextChapter(
      from: currentItem,
      after: chapter
    ) else { return nil }

    let fileExtension = nextChapter.fileURL.pathExtension

    /// Only check for audiovisual content if a file extension is present
    if !fileExtension.isEmpty,
       let fileType = UTType(filenameExtension: fileExtension),
       !fileType.isSubtype(of: .audiovisualContent) {
      return getNextPlayableChapter(
        currentItem: currentItem,
        after: nextChapter
      )
    }

    return nextChapter
  }

  @objc
  func playerDidFinishPlaying(_ notification: Notification) {
    guard let currentItem = self.currentItem else { return }

    let endOfChapterActive = SleepTimer.shared.state == .endOfChapter

    if currentItem.chapters.last == currentItem.currentChapter {
      self.libraryService.setLibraryLastBook(with: nil)

      self.markAsCompleted(true)

      self.playNextItem(autoPlayed: true, shouldAutoplay: !endOfChapterActive)

      NotificationCenter.default.post(name: .bookEnd, object: nil)
    } else if currentItem.isBoundBook {
      updatePlaybackTime(item: currentItem, time: currentItem.currentTime)
      /// Load next chapter
      guard
        let nextChapter = getNextPlayableChapter(
          currentItem: currentItem,
          after: currentItem.currentChapter
        )
      else { return }
      currentItem.currentChapter = nextChapter
      loadChapterMetadata(nextChapter, autoplay: !endOfChapterActive)
    }
  }

  /// Update the current item playback time, and checks for difference in progress percentage
  func updatePlaybackTime(item: PlayableItem, time: Float64) {
    let previousPercentage = Int(item.percentCompleted)
    self.playbackService.updatePlaybackTime(item: item, time: time)
    let newPercentage = Int(item.percentCompleted)

    if previousPercentage != newPercentage {
      if let parentFolder = item.parentFolder {
        if UIApplication.shared.applicationState == .active {
          libraryService.recursiveFolderProgressUpdate(from: parentFolder)
        } else {
          /// Defer all the folder progress updates until the user opens up the app again
          playbackService.markStaleProgress(folderPath: parentFolder)
        }
      }

      widgetReloadService.scheduleWidgetReload(of: .sharedNowPlayingWidget)
    }
  }

  private func loadAndRefreshURL(item: PlayableItem) {
    load(item, autoplay: playbackQueued == true, forceRefreshURL: true)
  }

  @objc
  private func handleMediaServicesWereReset() {
    /// Playback should be stopped, and wait for the user to activate it again
    if isPlaying {
      stopPlayback()
    }

    try? AVAudioSession.sharedInstance().setCategory(
      AVAudioSession.Category.playback,
      mode: .spokenAudio,
      options: []
    )

    setupPlayerInstance()
  }

  /// Playback may be interrupted by calls. Handle resuming the audio if needed
  @objc
  func handleAudioInterruptions(_ notification: Notification) {
    guard
      let userInfo = notification.userInfo,
      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    else {
      return
    }

    switch type {
    case .began:
      pause(removeInterruptObserver: false)
    case .ended:
      guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
        return
      }
      let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
      if options.contains(.shouldResume) {
        play()
      }
    @unknown default:
      break
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
  private func showErrorAlert(title: String, _ message: String?) {
    DispatchQueue.main.async {
      AppDelegate.shared?.activeSceneDelegate?
        .startingNavigationController
        .getTopVisibleViewController()?
        .showAlert(title, message: message)
    }
  }
}

// MARK: - Sleep timer
extension PlayerManager {
  private func handleSleepTimerThresholdEvent() {
    fadeTimer = audioPlayer.fadeVolume(from: 1, to: 0, duration: 5, completion: {})
    bindShakeObserver()
  }

  private func handleSleepTimerEndEvent(_ state: SleepTimerState) {
    pause()

    if state == .endOfChapter {
      bindShakeObserver()
    }
  }

  private func bindShakeObserver() {
    shakeMotionService.observeFirstShake { [weak self] in
      SleepTimer.shared.restartTimer()
      self?.play()
    }
  }
}
