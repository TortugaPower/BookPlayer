//
//  PlayerManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/31/17.
//  Copyright © 2017 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import Combine
import Foundation
import MediaPlayer

// swiftlint:disable:next file_length

/// Main-actor isolated: the load, the engine and every callback into them run on main. The protocol stays
/// nonisolated until rework PR 6c. What the app supplies comes through `PlayerPlatform`
@MainActor
public final class PlayerManager: NSObject, @preconcurrency PlayerManagerProtocol, ObservableObject {
  private let libraryService: LibraryServiceProtocol
  private let playbackService: PlaybackServiceProtocol
  /// Narrow read of the streaming entitlement (pro or lite), not the whole account
  /// service — the media-servers shortcut is only actionable for a tier that can stream.
  private let hasStreamingEnabled: () -> Bool
  /// Hands a failure to whichever surface the user is on. Injected because both failure sites
  /// are async and surface-agnostic — see `playbackFailure(for:title:message:)`. Always called
  /// through `presentOnMain(for:title:message:)`, never directly.
  private let presentFailure: (PlaybackFailure) -> Void
  private let syncService: SyncServiceProtocol
  private let speedService: SpeedServiceProtocol
  private let userActivityManager: UserActivityManager
  /// What differs by platform, or what a Kit may not touch
  private let platform: PlayerPlatform
  private let widgetReloadService: WidgetReloadServiceProtocol

  /// Drives the player. Only the engine and the video surfaces touch `AVPlayer`
  private let engine: PlaybackEngine

  #if os(iOS)
  /// The engine keeps its transport publisher across player rebuilds.
  private var groupPlaybackSubscription: AnyCancellable?
  #endif

  private var fadeTimer: Timer?

  /// Named + cancelled-before-rebind: bound on EVERY chapter/item load — a disposeBag entry
  /// leaks one KVO publisher (which retains its AVPlayerItem) per loaded chapter.
  private var playableChapterSubscription: AnyCancellable?
  private var isPlayingSubscription: AnyCancellable?
  /// Tracks the brief muted play used to claim Now Playing on CarPlay connect, so we can pause once it starts
  private var nowPlayingClaimSubscription: AnyCancellable?
  /// The 1 s tick, which the engine keeps across rebuilds
  private var tickObservation: EngineObservation?
  /// The chapter ends inside the file in the player, which the engine reports as playback crosses them
  private var chapterBoundaryObservation: EngineObservation?
  private var disposeBag = Set<AnyCancellable>()
  /// Observes `AVAudioSession.interruptionNotification` while playing, and through an interruption
  private var interruptionSubscription: AnyCancellable?
  /// Whether playback should start once the item can play, and who asked for it
  @Published private var playIntent: PlayIntent = .idle
  /// The chapter file going into the player. Leaving a state cancels what it holds: a resolve its task, a
  /// load its engine observers. A resolve handing its file to the engine, and a load becoming ready, keep theirs
  private var itemLoad: ItemLoad = .empty {
    didSet {
      switch oldValue {
      case .resolving(_, let task):
        if case .loading = itemLoad { break }
        task.cancel()
      case .loading(_, let load), .ready(_, let load):
        if itemLoad.engineLoad !== load {
          load.cancel()
        }
      case .empty, .failed:
        break
      }
    }
  }
  /// The reloads a failed file gets before its failure is reported
  private var retryBudget = RetryBudget()
  /// Asks an AudiobookShelf server for an item's files when one of its chapters loads.
  private let streamLookup: ExternalStreamLooking
  /// How the server item the current item streams from answered, asked once per item: a
  /// volume's books share one lookup, and after a failed one go straight to the cloud copy
  /// instead of waiting out the timeout at every file. Dropped on a forced refresh (a file
  /// replaced since) and when a failed item is loaded again.
  private var cachedStreamFiles: (key: String, answer: ExternalStreamFiles, date: Date)?
  /// How long a failed lookup is reused: long enough for a volume's next files, short enough
  /// that a server back from an outage serves them again.
  private static let failedStreamLookupLifetime: TimeInterval = 120
  /// How far we trust the player's clock: the baseline for spotting moves the player makes on its own
  private var clockState: ClockState = .unknown
  /// The last seek started, as only its completion ends `ClockState.seeking`
  private var latestSeek = 0

  public weak var syncProgressDelegate: PlaybackSyncProgressDelegate?
  /// Reference to the ongoing play task
  private var playTask: Task<(), Error>?
  @Published public var currentItem: PlayableItem? {
    didSet {
      #if os(iOS)
      // Metadata can be re-parsed without replacing the engine's current player item.
      engine.refreshPlaybackCoordination()
      #endif
    }
  }
  @Published public var currentSpeed: Float = 1.0

  var nowPlayingInfo = [String: Any]()

  /// The app's player, on an `AVPlayerEngine`
  public convenience init(
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol,
    speedService: SpeedServiceProtocol,
    platform: PlayerPlatform,
    widgetReloadService: WidgetReloadServiceProtocol,
    hasStreamingEnabled: @escaping () -> Bool,
    presentFailure: @escaping (PlaybackFailure) -> Void,
    streamLookup: ExternalStreamLooking = AudiobookShelfStreamLookup()
  ) {
    self.init(
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService,
      speedService: speedService,
      platform: platform,
      widgetReloadService: widgetReloadService,
      hasStreamingEnabled: hasStreamingEnabled,
      presentFailure: presentFailure,
      streamLookup: streamLookup,
      engine: nil
    )
  }

  /// `engine` is the Kit's own seam, which tests drive; `nil` for an `AVPlayerEngine`
  init(
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol,
    speedService: SpeedServiceProtocol,
    platform: PlayerPlatform,
    widgetReloadService: WidgetReloadServiceProtocol,
    hasStreamingEnabled: @escaping () -> Bool,
    presentFailure: @escaping (PlaybackFailure) -> Void,
    streamLookup: ExternalStreamLooking = AudiobookShelfStreamLookup(),
    engine: PlaybackEngine?
  ) {
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.syncService = syncService
    self.speedService = speedService
    self.userActivityManager = UserActivityManager(libraryService: libraryService)
    self.platform = platform
    self.widgetReloadService = widgetReloadService
    self.hasStreamingEnabled = hasStreamingEnabled
    self.presentFailure = presentFailure
    self.streamLookup = streamLookup
    self.engine = engine ?? AVPlayerEngine()
    super.init()

    /// The engine runs its observers on the main queue
    tickObservation = self.engine.addPeriodicObserver(every: 1) { [weak self] in
      MainActor.assumeIsolated {
        self?.updateTime()
      }
    }
    bindObservers()
  }

  /// Runs `body` on the main actor: right away when already on main, so a change made there takes effect in
  /// that same turn (the end-of-chapter timer pausing as the chapter changes), otherwise on main's next turn
  /// (Siri and Shortcuts set the sleep timer off main, and AVAudioSession doesn't promise main)
  nonisolated private static func onMain(_ body: @escaping @MainActor () -> Void) {
    if Thread.isMainThread {
      MainActor.assumeIsolated(body)
    } else {
      Task { @MainActor in body() }
    }
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
      .sink { [weak self] _ in
        Self.onMain { self?.handleMediaServicesWereReset() }
      }
      .store(in: &disposeBag)

    SleepTimer.shared.countDownThresholdPublisher.sink { [weak self] _ in
      Self.onMain { self?.handleSleepTimerThresholdEvent() }
    }.store(in: &disposeBag)

    SleepTimer.shared.timerEndedPublisher.sink { [weak self] state in
      Self.onMain { self?.handleSleepTimerEndEvent(state) }
    }.store(in: &disposeBag)

    SleepTimer.shared.timerTurnedOnPublisher.sink { [weak self] _ in
      Self.onMain { self?.handleSleepTimerTurnedOnEvent() }
    }.store(in: &disposeBag)

    isPlayingPublisher()
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isPlayingValue in
        if isPlayingValue {
          UserDefaults.sharedDefaults.set(
            self?.currentItem?.relativePath,
            forKey: Constants.UserDefaults.sharedWidgetNowPlayingPath
          )
        } else {
          UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.sharedWidgetNowPlayingPath)
        }
      }.store(in: &disposeBag)
  }

  func bindInterruptObserver() {
    interruptionSubscription = NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
      .sink { [weak self] notification in
        Self.onMain { self?.handleAudioInterruptions(notification) }
      }
  }

  public func currentItemPublisher() -> AnyPublisher<PlayableItem?, Never> {
    return self.$currentItem.eraseToAnyPublisher()
  }

  /// An item never outlives its book: `stop()` drops both
  public func hasLoadedBook() -> Bool {
    currentItem != nil
  }

  func loadRemoteURLAsset(for chapter: PlayableChapter, forceRefresh: Bool) async throws -> AVURLAsset {
    let fileURL: URL
    if !forceRefresh,
      let chapterURL = chapter.remoteURL
    {
      fileURL = chapterURL
    } else {
      // For a bound book the chapter is a child file and `currentItem` is the parent:
      // sending the parent's uuid would make the API return the parent row (no file
      // URL) instead of this chapter, so resolve bound chapters by path only.
      let itemUUID = currentItem?.isBoundBook == true ? nil : currentItem?.uuid
      fileURL =
        try await syncService
        .getRemoteFileURLs(of: chapter.relativePath, for: itemUUID, type: .book)[0].url
      /// Cancelled by a newer load or a pause
      guard !Task.isCancelled else {
        throw BookPlayerError.cancelledTask
      }
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
      "metadata",
    ])

    guard !Task.isCancelled else {
      throw BookPlayerError.cancelledTask
    }

    /// Load artwork if it's not cached
    if !ArtworkService.isCached(relativePath: chapter.relativePath),
      let data = AVMetadataItem.metadataItems(
        from: asset.commonMetadata,
        filteredByIdentifier: .commonIdentifierArtwork
      ).first?.dataValue
    {
      await ArtworkService.storeInCache(data, for: chapter.relativePath)
    }

    if currentItem?.isBoundBook == false {
      await libraryService.loadChaptersIfNeeded(relativePath: chapter.relativePath, asset: asset)

      if let libraryItem = libraryService.getSimpleItem(with: chapter.relativePath) {
        currentItem = try playbackService.getPlayableItem(from: libraryItem)
        if let currentItem {
          /// `currentItem` was replaced — re-bind the chapter-change subscription
          /// to the new instance so end-of-chapter sleep timer keeps working.
          /// `dropInitialReplay: true` is safe only because `PlayableItem.init`
          /// seeds `currentChapter` from `currentTime` (see PlayableItem.swift).
          bindPlayableChapterSubscription(to: currentItem, dropInitialReplay: true)
        }
      }
    } else if currentItem?.isBoundBook == true, chapter.relativePath.hasSuffix(".m4b") {
      /// recently synced m4b files do not have their chapters loaded outright
      await libraryService.loadChaptersIfNeeded(relativePath: chapter.relativePath, asset: asset)
    }

    return asset
  }

  /// Finds where `chapter`'s file is and prepares its asset for the engine: on disk, its media server's
  /// stream, or the cloud copy
  func resolveAsset(for chapter: PlayableChapter, forceRefresh forceRefreshURL: Bool) async throws -> AVURLAsset {
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(chapter.relativePath)
    let isMissingLocally = !FileManager.default.fileExists(atPath: fileURL.path)

    let asset: AVURLAsset

    if isMissingLocally, hasStreamingEnabled(), chapter.isStreamed {
      // Media-server chapters stream from their server first — a forced refresh must not
      // reroute them to the cloud/S3 presign path while the server serves them. The
      // entitlement is checked HERE rather than only at import: the rows outlive the
      // subscription that created them, and the stream reaches the user's own server, so
      // nothing server-side can gate it.
      switch try await streamURL(for: chapter, forceRefresh: forceRefreshURL) {
      case .success(let streamURL):
        // No metadata is loaded here: the length comes from the server at import time
        // (`VirtualImportPipeline` refuses an item without one), so there is nothing a round
        // trip to the stream could add. `AVURLAssetHTTPHeaderFieldsKey` is undocumented, but it
        // is the only way to attach the server's auth header short of an
        // AVAssetResourceLoaderDelegate.
        asset = AVURLAsset(url: streamURL, options: [
          AVURLAssetPreferPreciseDurationAndTimingKey: false,
          "AVURLAssetHTTPHeaderFieldsKey": chapter.externalHeaders
        ])
      case .failure(let failure):
        // The server didn't serve it (unreachable away from home, or gone): the cloud copy
        // may, once a download uploaded one. Nothing serves it otherwise, and the alert
        // says why (`loadChapterMetadata`)
        guard let cloudAsset = try await cloudAssetIfAvailable(for: chapter, forceRefresh: forceRefreshURL) else {
          throw failure
        }
        asset = cloudAsset
      }
    } else if isMissingLocally, syncService.isActive {
      asset = try await loadRemoteURLAsset(for: chapter, forceRefresh: forceRefreshURL)
    } else {
      /// The file is on disk — or it is missing with no remote source, and AVFoundation
      /// surfaces that as a player-item failure.
      asset = AVURLAsset(url: fileURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    }

    // A load that started after this one, or a pause, owns the player now
    guard !Task.isCancelled else {
      throw BookPlayerError.cancelledTask
    }

    return asset
  }

  /// Why a media server didn't serve a chapter.
  enum StreamFailure: Error, Equatable {
    /// The server rejected the saved token (401): the user has to sign in again.
    case sessionExpired
    /// It didn't answer in time, can't be reached, answered with an error, or has no file
    /// for the chapter.
    case unavailable
  }

  /// Where the media server serves `chapter`: Jellyfin's URL as it is, or the AudiobookShelf
  /// file its server lists right now. Only looked up when a chapter loads, never ahead of it.
  func streamURL(for chapter: PlayableChapter, forceRefresh: Bool) async throws -> Result<URL, StreamFailure> {
    if let externalUrl = chapter.externalUrl {
      return .success(externalUrl)
    }
    guard let lookup = chapter.streamLookup else { return .failure(.unavailable) }

    let key = "\(currentItem?.uuid ?? "")|\(lookup.serverURL.absoluteString)|\(lookup.itemId)"
    let answer: ExternalStreamFiles
    if !forceRefresh, let cached = cachedStreamFiles, cached.key == key, Self.isReusable(cached.answer, since: cached.date) {
      answer = cached.answer
    } else {
      cachedStreamFiles = nil
      answer = await streamLookup.files(
        ofItem: lookup.itemId,
        on: lookup.serverURL,
        headers: chapter.externalHeaders,
        timeout: ExternalStreamLookupTimeout.playback
      )

      /// Cancelled by a newer load or a pause
      guard !Task.isCancelled else {
        throw BookPlayerError.cancelledTask
      }

      cachedStreamFiles = (key, answer, Date())
    }

    switch answer {
    case .answered(let files):
      // None when the item is gone, or several files were imported as one book (before
      // volumes): playing only the first of them would be worse than saying it can't play
      guard let file = lookup.file(in: files) else { return .failure(.unavailable) }

      return .success(file.url(on: lookup.serverURL))
    case .sessionExpired:
      return .failure(.sessionExpired)
    case .unreachable, .failed:
      return .failure(.unavailable)
    }
  }

  private static func isReusable(_ answer: ExternalStreamFiles, since date: Date) -> Bool {
    guard case .answered = answer else {
      return Date().timeIntervalSince(date) < failedStreamLookupLifetime
    }

    return true
  }

  /// The cloud copy of a streamed chapter its server didn't serve, if the account syncs and
  /// the cloud has one.
  private func cloudAssetIfAvailable(for chapter: PlayableChapter, forceRefresh: Bool) async throws -> AVURLAsset? {
    guard syncService.isActive else { return nil }

    do {
      return try await loadRemoteURLAsset(for: chapter, forceRefresh: forceRefresh)
    } catch BookPlayerError.cancelledTask {
      throw BookPlayerError.cancelledTask
    } catch {
      // A cancelled request fails as URLError(.cancelled): still a cancellation
      if Task.isCancelled {
        throw BookPlayerError.cancelledTask
      }
      return nil
    }
  }

  public func load(_ item: PlayableItem, intent: PlayIntent) {
    load(item, intent: intent, forceRefreshURL: false)
  }

  public func awaitCurrentLoad() async {
    await withCheckedContinuation { continuation in
      var playedObserver: NSObjectProtocol?
      var readyObserver: NSObjectProtocol?
      var timeoutTask: Task<Void, Never>?

      func cleanup() {
        timeoutTask?.cancel()
        if let playedObserver { NotificationCenter.default.removeObserver(playedObserver) }
        if let readyObserver { NotificationCenter.default.removeObserver(readyObserver) }
      }

      playedObserver = NotificationCenter.default.addObserver(
        forName: .bookPlayed, object: nil, queue: .main
      ) { _ in
        cleanup()
        continuation.resume()
      }

      readyObserver = NotificationCenter.default.addObserver(
        forName: .bookReady, object: nil, queue: .main
      ) { notification in
        if notification.userInfo?["loaded"] as? Bool == false {
          cleanup()
          continuation.resume()
        }
      }

      timeoutTask = Task { @MainActor in
        try? await Task.sleep(nanoseconds: 30_000_000_000)
        guard !Task.isCancelled else { return }
        cleanup()
        continuation.resume()
      }
    }
  }

  private func load(_ item: PlayableItem, intent: PlayIntent, forceRefreshURL: Bool) {
    /// Cancel in case there's an ongoing play task
    playTask?.cancel()
    clockState = .unknown

    // Recover in case of failure
    if engine.hasFailed {
      engine.rebuild()
    }

    // Preload item
    if self.currentItem != nil {
      stopPlayback()
      currentItem = nil
    }

    self.currentItem = item

    bindPlayableChapterSubscription(to: item, dropInitialReplay: false)

    loadChapterMetadata(item.currentChapter, intent: intent, forceRefreshURL: forceRefreshURL)
    storeWidgetItem(item)
  }

  /// Subscribes the chapter-change pipeline to a `PlayableItem` instance.
  /// Must be called again whenever `currentItem` is swapped, otherwise
  /// `.chapterChange` (which the end-of-chapter sleep timer listens for)
  /// publishes on an orphaned instance.
  private func bindPlayableChapterSubscription(to item: PlayableItem, dropInitialReplay: Bool) {
    self.playableChapterSubscription?.cancel()
    let publisher = item.$currentChapter
    let stream: AnyPublisher<PlayableChapter?, Never> =
      dropInitialReplay
      ? publisher.dropFirst().eraseToAnyPublisher()
      : publisher.eraseToAnyPublisher()
    self.playableChapterSubscription = stream.sink { [weak self] chapter in
      guard let chapter = chapter else { return }

      self?.setNowPlayingBookTitle(chapter: chapter)
      NotificationCenter.default.post(name: .chapterChange, object: nil, userInfo: nil)
      self?.widgetReloadService.scheduleWidgetReload(of: .sharedNowPlayingWidget)
    }
  }

  func storeWidgetItem(_ item: PlayableItem) {
    SharedWidgetStore.store(item)
  }

  /// Whether a failed load should offer the Media Servers shortcut: the tier can stream at
  /// all, and going to Media Servers could actually fix this chapter's failure. Not private
  /// so the entitlement wiring itself is testable.
  func offersMediaServers(for chapter: PlayableChapter) -> Bool {
    hasStreamingEnabled() && chapter.needsMediaServer()
  }

  /// A failure described for whichever surface ends up showing it. Shared by both failure
  /// sites so the reason and the offer can't drift between the metadata path and the
  /// player-item path.
  ///
  /// This only DESCRIBES the failure. Presenting it is the arbiter's job: both call sites are
  /// asynchronous — a detached metadata task and a KVO status callback — so by the time either
  /// fires, whichever surface asked for playback is long gone from the stack.
  ///
  /// Not private so the reason derivation is testable without provoking a real AVFoundation
  /// failure, same as `offersMediaServers(for:)`.
  func playbackFailure(
    for chapter: PlayableChapter?,
    title: String,
    message: String?,
    streamFailure: StreamFailure? = nil
  ) -> PlaybackFailure {
    /// `needsMediaServer()` gates BOTH media-server reasons, because it is the only one of the
    /// two predicates that checks the filesystem: `hasUnresolvedExternalHost` is a stored flag
    /// that stays true on a DOWNLOADED book whose connection was later removed. Reading it
    /// first would have blamed a missing server for a local file that simply won't open, and
    /// reported a reason that disagrees with `canOfferMediaServers` on the same value.
    let reason: PlaybackFailure.Reason

    if let chapter, chapter.needsMediaServer() {
      if streamFailure == .sessionExpired {
        reason = .sessionExpired
      } else {
        reason = chapter.hasUnresolvedExternalHost ? .missingConnection : .streamUnavailable
      }
    } else {
      reason = .other
    }

    let canOfferMediaServers = chapter.map(offersMediaServers(for:)) ?? false
    let phoneMessage: String?
    switch (reason, streamFailure) {
    case (.sessionExpired, _):
      phoneMessage = "playback_error_session_expired".localized
    // Its server was asked and didn't serve it: there's no AVFoundation error to show
    case (.streamUnavailable, .unavailable):
      phoneMessage = "playback_error_server_unavailable".localized
    default:
      phoneMessage = missingServerMessage(reason: reason, host: chapter?.unresolvedHost, canOfferMediaServers: canOfferMediaServers)
    }

    return PlaybackFailure(
      reason: reason,
      phoneTitle: title,
      phoneMessage: phoneMessage ?? message,
      canOfferMediaServers: canOfferMediaServers
    )
  }

  /// Names the server to add when the item says where it is. Without an address (a Jellyfin
  /// server id, or a legacy `"server-settings"` hostId) the phone keeps its usual copy, and so
  /// it does for a tier that can't stream: adding the server wouldn't play the book, which is
  /// why the car and the Media Servers button stay quiet then too.
  private func missingServerMessage(
    reason: PlaybackFailure.Reason,
    host: PlayableChapter.UnresolvedHost?,
    canOfferMediaServers: Bool
  ) -> String? {
    guard
      reason == .missingConnection,
      canOfferMediaServers,
      let address = host?.address,
      let provider = host?.provider
    else { return nil }

    return String(format: "integration_error_missing_connection_address".localized, provider.displayName, address)
  }

  /// The one way a failure leaves this class. Presents on main's next turn, as the UIKit
  /// presentation this replaced did, so a presenter never runs in the middle of a load's state
  /// change. Every presenter writes `@Observable` state or puts a template on screen.
  ///
  /// It BUILDS the failure inside the hop, not just presents it: `playbackFailure` reaches
  /// `hasStreamingEnabled()`, which reads `donationMade` through `AccountService.getAccount()`
  /// — a fetch on the VIEW context. The caller still resolves `chapter` itself, so the
  /// snapshot is taken when the failure occurs rather than a turn later.
  private func presentOnMain(
    for chapter: PlayableChapter?,
    title: String,
    message: String?,
    streamFailure: StreamFailure? = nil
  ) {
    Task { @MainActor in
      self.presentFailure(
        self.playbackFailure(for: chapter, title: title, message: message, streamFailure: streamFailure)
      )
    }
  }

  /// Loads `chapter`'s file into the player, replacing any load under way
  func loadChapterMetadata(_ chapter: PlayableChapter, intent: PlayIntent? = nil, forceRefreshURL: Bool = false) {
    if let intent {
      playIntent = intent
    }

    /// A media-server chapter's resolve waits on its server: one still in flight for another
    /// chapter is cancelled, so it can't land after this one
    itemLoad = .resolving(
      chapter,
      Task { [weak self] in
        await self?.resolveAndLoad(chapter, forceRefresh: forceRefreshURL)
      }
    )
  }

  /// `.resolving`'s task: finds the file, then hands it to the engine
  private func resolveAndLoad(_ chapter: PlayableChapter, forceRefresh: Bool) async {
    do {
      let asset = try await resolveAsset(for: chapter, forceRefresh: forceRefresh)
      /// The chapter as it is now: a cloud file's metadata can rebuild the item with its chapters
      startLoading(asset, for: currentItem?.currentChapter ?? chapter)
    } catch _ where Task.isCancelled {
      /// Superseded by a newer load or a pause, whichever failed: the state belongs to it now
    } catch BookPlayerError.cancelledTask {
      /// A request cancelled underneath: nothing to say, and the next play finds the file again
      itemLoad = .failed(chapter)
    } catch let failure as StreamFailure {
      /// Said only for a play that was asked for or one under way (a chapter skip while
      /// playing): a silent load (the last book, at launch) stays quiet, and the next tap
      /// loads it again (`reloadable`)
      if unloadAfterFailing(chapter) {
        presentOnMain(for: chapter, title: "error_title".localized, message: nil, streamFailure: failure)
      }
    } catch {
      unloadAfterFailing(chapter)
      presentOnMain(
        for: chapter,
        title: "\("error_title".localized) Metadata",
        message: error.localizedDescription
      )
    }
  }

  /// Drops the player's item after `chapter`'s file couldn't be found: on a chapter change inside a
  /// volume the previous file's item is still loaded, and playing it would save its time against the
  /// new chapter. The next play loads the book again.
  ///
  /// Pauses first if it was playing (a chapter skip mid-playback) or about to (the next file of a
  /// volume, after the last one ended): the player keeps its rate with no item, and the session,
  /// Now Playing and the interruption observer would go on as if it played. Returns whether it was.
  @discardableResult
  private func unloadAfterFailing(_ chapter: PlayableChapter) -> Bool {
    let playWanted = playIntent != .idle || engine.rate != 0
    playIntent = .idle
    itemLoad = .failed(chapter)
    if playWanted {
      pause()
    }
    engine.unload()

    return playWanted
  }

  /// Hands `chapter`'s file to the engine, and sets up Now Playing and the position for it
  private func startLoading(_ asset: AVURLAsset, for chapter: PlayableChapter) {
    // `duration > 0` is load-bearing for PLAYBACK, not just hygiene: failing it posts
    // `.bookReady loaded:false`, which only CarPlay and the watch observe, so the user
    // sees the spinner clear and nothing happen. Media-server rows can't land here with
    // a 0 duration — `HydratedItem` refuses to import one — and that is what lets the
    // external branch of `resolveAsset` skip loading metadata off the stream.
    guard chapter.duration > 0 else {
      playIntent = .idle
      itemLoad = .failed(chapter)
      NotificationCenter.default.post(name: .bookReady, object: nil, userInfo: ["loaded": false])
      return
    }

    itemLoad = .loading(
      chapter,
      engine.load(asset) { [weak self] event in
        self?.handle(event)
      }
    )
    observeChapterEnds(inFileOf: chapter)
    clockState = .trusting(0)

    currentSpeed = speedService.getSpeed(relativePath: chapter.relativePath)
    // Set book metadata for lockscreen and control center
    nowPlayingInfo = [
      MPNowPlayingInfoPropertyDefaultPlaybackRate: currentSpeed
    ]

    setNowPlayingBookTitle(chapter: chapter)
    setNowPlayingBookTime()
    setNowPlayingArtwork(chapter: chapter)

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    MPNowPlayingInfoCenter.default().playbackState = .playing

    if let currentItem {
      // if book is truly finished, start book again to avoid autoplaying next one
      // add 1 second as a finished threshold
      if currentItem.currentTime > 0.0 {
        let time = (currentItem.currentTime + 1) >= currentItem.duration ? 0 : currentItem.currentTime
        initializeChapterTime(time)
      }
    }

    NotificationCenter.default.post(name: .bookReady, object: nil, userInfo: ["loaded": true])
    widgetReloadService.reloadAllWidgets()
  }

  /// What the engine reports about the file it's loading, or loaded
  private func handle(_ event: LoadEvent) {
    switch event {
    case .ready:
      guard case .loading(let chapter, let load) = itemLoad else { return }

      itemLoad = .ready(chapter, load)
      /// The play keeps the origin it was asked with: one pressed during the load is still the user's
      if case .wantsToPlay(let origin) = playIntent {
        play(origin: origin)
      }
      // Clean up flag
      playIntent = .idle
    case .failed(let error):
      handleLoadFailure(error)
    case .ended:
      playerDidFinishPlaying()
    }
  }

  /// The file reached the engine but can't play: reloaded while the retry budget allows, else reported
  private func handleLoadFailure(_ error: Error?) {
    guard case .loading(let chapter, _) = itemLoad, let currentItem else { return }

    if retryBudget.spend(on: error, for: chapter) {
      loadAndRefreshURL(item: currentItem)
      return
    }

    /// Avoid showing any alert if playback is not queued, this could be from the initial app launch
    /// where we preload the player with the last played item
    if playIntent != .idle {
      if let nsError = error as? NSError {
        let errorDescription = """
          \(nsError.localizedDescription)

          Error Domain
          \(nsError.domain)

          Additional Info
          \(nsError.userInfo)
          """
        presentOnMain(
          for: chapter,
          title: "\("error_title".localized) \(nsError.code)",
          message: errorDescription
        )
      } else {
        presentOnMain(
          for: chapter,
          title: "error_title".localized,
          message: error?.localizedDescription
        )
      }
    }

    playIntent = .idle
    itemLoad = .failed(chapter)
  }

  func setNowPlayingArtwork(chapter: PlayableChapter) {
    var pathForArtwork = chapter.relativePath

    if !ArtworkService.isCached(relativePath: chapter.relativePath),
      let currentItem = currentItem
    {
      pathForArtwork = currentItem.relativePath
    }

    ArtworkService.retrieveImageFromCache(for: pathForArtwork) { [weak self] result in
      guard let self else { return }

      let image: UIImage

      switch result {
      case .success(let value):
        image = value.image
      case .failure:
        /// A platform without a fallback shows no artwork
        guard let fallback = self.platform.fallbackArtwork() else { return }
        image = fallback
      }

      self.nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
        boundsSize: image.size,
        requestHandler: { (_) -> UIImage in
          image
        }
      )

      MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo
    }
  }

  /// The chapter file going into the player, and how far it got
  private enum ItemLoad {
    case empty
    /// Finding the file: a cloud URL, a media server's stream, or a cloud file's metadata
    case resolving(PlayableChapter, Task<Void, Never>)
    /// The engine is opening it
    case loading(PlayableChapter, EngineLoad)
    /// It can play; the engine still reports its end
    case ready(PlayableChapter, EngineLoad)
    /// The next play loads the book again
    case failed(PlayableChapter)

    /// The chapter whose file it is
    var chapter: PlayableChapter? {
      switch self {
      case .empty:
        return nil
      case .resolving(let chapter, _), .loading(let chapter, _), .ready(let chapter, _), .failed(let chapter):
        return chapter
      }
    }

    /// Set once the file is in the engine
    var engineLoad: EngineLoad? {
      switch self {
      case .loading(_, let load), .ready(_, let load):
        return load
      case .empty, .resolving, .failed:
        return nil
      }
    }
  }

  /// The reloads a file that failed in the engine gets before the failure is reported. A play asked for
  /// refills it, so automatic reloads can't loop
  private struct RetryBudget {
    /// A cloud file whose URL expired or was refused: fetch a new one
    private var urlRefresh = true
    /// A media-server stream: one retry for a transient failure. It replays the same item, so the auth
    /// headers are the same; it recovers a blip, or an AudiobookShelf file replaced since its lookup,
    /// never a rotated token (signing in again and tapping the book reloads it rebuilt, `reloadable`)
    private var streamRetry = true

    /// Whether `error` on `chapter`'s file gets a reload, spending it
    mutating func spend(on error: Error?, for chapter: PlayableChapter) -> Bool {
      let code = (error as? NSError)?.code

      if urlRefresh, code == NSURLErrorResourceUnavailable || code == NSURLErrorNoPermissionsToReadFile {
        urlRefresh = false
        return true
      }

      if streamRetry, chapter.isStreamed {
        streamRetry = false
        return true
      }

      return false
    }
  }

  /// How far `PlayerManager` trusts the player's clock (see `PlayerTimeSample`). Times are relative
  /// to the current file
  private enum ClockState {
    /// Nothing loaded, so there's no baseline yet
    case unknown
    /// Readings are judged against `expected`, which comes from our own seeks and from every
    /// accepted reading. `recoveries` counts the seeks back since the last accepted reading
    case tracking(expected: TimeInterval, recoveries: Int)
    /// A seek of ours to `target` is in flight, and the player still reports the position it left
    case seeking(target: TimeInterval, recoveries: Int)

    /// Trust a position we just put the player at, or that it just reported
    static func trusting(_ time: TimeInterval) -> ClockState {
      .tracking(expected: time, recoveries: 0)
    }

    var expectedTime: TimeInterval? {
      switch self {
      case .unknown:
        return nil
      case .tracking(let expected, _):
        return expected
      case .seeking(let target, _):
        return target
      }
    }
  }

  /// Caps the seeks back in a row, so a clock that stays broken can't loop seeks
  private static let maxClockRecoveries = 3

  /// Seek back to the last trusted position after the player moved on its own (see `PlayerTimeSample`)
  private func recoverPlayerTime() {
    guard
      case .tracking(let expected, let recoveries) = clockState,
      recoveries < Self.maxClockRecoveries
    else { return }

    seekPlayer(to: expected, recoveries: recoveries + 1)
  }

  /// Every seek of ours goes through here. Readings before it lands are the position it's leaving:
  /// accepting one would make the landing look like the player moved on its own, and the clock
  /// recovery would undo the seek (GH #1641)
  private func seekPlayer(to time: TimeInterval, recoveries: Int = 0, precisely: Bool = false) {
    clockState = .seeking(target: time, recoveries: recoveries)
    latestSeek += 1
    let seek = latestSeek

    engine.seek(to: time, precisely: precisely) { [weak self] _ in
      DispatchQueue.main.async {
        /// Unless a newer seek took over, or the item it was for is gone
        guard
          let self,
          seek == self.latestSeek,
          case .seeking(let target, let recoveries) = self.clockState
        else { return }

        self.clockState = .tracking(expected: target, recoveries: recoveries)
        /// While paused, the tick for this seek arrived before it landed and was dropped, and no
        /// other tick follows: publish the landed position now, or the UI keeps the old one
        self.updateTime()
      }
    }
  }

  /// iOS 27 can snap a paused item back to the file start (see `PlayerTimeSample`), so put it back
  /// where we left it before resuming
  private func restorePlayerTimeIfNeeded() {
    guard
      case .tracking(let expected, _) = clockState,
      PlayerTimeSample(playerTime: engine.currentTime, expected: expected) == .recover
    else { return }

    seekPlayer(to: expected)
  }

  // Called every second by the timer
  func updateTime() {
    guard
      let currentItem,
      case .ready = itemLoad
    else {
      return
    }

    reconcileGroupPlaybackRate()

    /// A seek is in flight, and its target is the position we already hold
    if case .seeking = clockState { return }

    var currentTime: TimeInterval

    switch PlayerTimeSample(
      playerTime: self.engine.currentTime,
      expected: clockState.expectedTime
    ) {
    case .valid(let playerTime):
      clockState = .trusting(playerTime)
      currentTime = playerTime
    case .ignore:
      return
    case .recover:
      recoverPlayerTime()
      return
    }

    if currentItem.isBoundBook {
      currentTime += (currentItem.currentChapter.start - currentItem.currentChapter.chapterOffset)
    }

    if currentTime >= currentItem.currentChapter.end || currentTime < currentItem.currentChapter.start,
      let newChapter = currentItem.getChapter(at: currentTime),
      newChapter != currentItem.currentChapter,
      !currentItem.isBoundBook || newChapter.chapterOffset != 0
    {
      /// Avoid setting the same chapter, as it would publish an update event
      currentItem.currentChapter = newChapter
    }

    updatePlaybackTime(item: currentItem, time: currentTime)

    self.userActivityManager.recordTime()

    self.setNowPlayingBookTime()

    MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo

    NotificationCenter.default.post(name: .bookPlaying, object: nil, userInfo: nil)
  }

  // MARK: - Player states

  public var isPlaying: Bool {
    engine.status != .paused || playIntent != .idle
  }

  func bindPauseObserver() {
    self.isPlayingSubscription?.cancel()
    self.isPlayingSubscription =
      engine.statusPublisher
      .delay(for: .seconds(0.1), scheduler: RunLoop.main, options: .none)
      .sink { status in
        if status == .paused {
          self.platform.deactivateAudioSession()
          self.isPlayingSubscription?.cancel()
        }
      }
  }

  public func isPlayingPublisher() -> AnyPublisher<Bool, Never> {
    return Publishers.CombineLatest(engine.statusPublisher, $playIntent)
      .map { status, playIntent in
        status != .paused || playIntent != .idle
      }
      .eraseToAnyPublisher()
  }

  public func currentProgressPublisher() -> AnyPublisher<(String, Double), Never> {
    $currentItem
      .removeDuplicates(by: { lhs, rhs in
        lhs?.relativePath == rhs?.relativePath
      })
      .map { item -> AnyPublisher<(String, Double), Never> in
        guard let item = item else {
          return Combine.Empty<(String, Double), Never>(completeImmediately: false)
            .eraseToAnyPublisher()
        }

        return item.publisher(for: \.percentCompleted, options: [.initial, .new])
          .map { percentCompleted in
            let progress = item.isFinished ? 1.0 : percentCompleted / 100
            return (item.relativePath, progress)
          }
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  var boostVolume: Bool = false {
    didSet {
      self.engine.volume =
        self.boostVolume
        ? Constants.Volume.boosted
        : Constants.Volume.normal
    }
  }

  nonisolated public static var rewindInterval: TimeInterval {
    get {
      if UserDefaults.standard.object(forKey: Constants.UserDefaults.rewindInterval) == nil {
        return 30.0
      }

      return UserDefaults.standard.double(forKey: Constants.UserDefaults.rewindInterval)
    }

    set {
      UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.rewindInterval)

      let center = MPRemoteCommandCenter.shared()
      if newValue == Constants.SkipInterval.chapterSkipValue {
        center.skipBackwardCommand.isEnabled = false
      } else {
        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [newValue] as [NSNumber]
      }
    }
  }

  nonisolated public static var forwardInterval: TimeInterval {
    get {
      if UserDefaults.standard.object(forKey: Constants.UserDefaults.forwardInterval) == nil {
        return 30.0
      }

      return UserDefaults.standard.double(forKey: Constants.UserDefaults.forwardInterval)
    }

    set {
      UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.forwardInterval)

      let center = MPRemoteCommandCenter.shared()
      if newValue == Constants.SkipInterval.chapterSkipValue {
        center.skipForwardCommand.isEnabled = false
      } else {
        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [newValue] as [NSNumber]
      }
    }
  }

  nonisolated public static var isRewindChapterSkip: Bool {
    rewindInterval == Constants.SkipInterval.chapterSkipValue
  }

  nonisolated public static var isForwardChapterSkip: Bool {
    forwardInterval == Constants.SkipInterval.chapterSkipValue
  }

  func setNowPlayingBookTitle(chapter: PlayableChapter) {
    guard let currentItem = self.currentItem else { return }

    self.nowPlayingInfo[MPMediaItemPropertyTitle] = chapter.title

    /// If the chapter title is the same as the current item, show the author instead
    if currentItem.isBoundBook || chapter.title == currentItem.title {
      self.nowPlayingInfo[MPMediaItemPropertyArtist] = currentItem.author
    } else {
      self.nowPlayingInfo[MPMediaItemPropertyArtist] = currentItem.title
    }
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
  public func jumpToChapter(_ chapter: PlayableChapter) {
    jumpTo(chapter.start + 0.1, recordBookmark: false)
  }

  public func reloadCurrentItem() {
    // Rebuild the in-memory item from storage so externally-changed data (e.g. re-parsed
    // chapters) takes effect. Playback position is preserved — it's persisted in Core Data and
    // re-seeded by time in `PlayableItem.init` — and the chapter-change subscription must be
    // re-bound to the new instance, otherwise the end-of-chapter sleep timer silently breaks.
    guard let relativePath = currentItem?.relativePath,
          let libraryItem = libraryService.getSimpleItem(with: relativePath),
          let updatedItem = try? playbackService.getPlayableItem(from: libraryItem) else {
      return
    }
    currentItem = updatedItem
    bindPlayableChapterSubscription(to: updatedItem, dropInitialReplay: true)
    /// The re-parsed chapters end elsewhere in the file playing
    if itemLoad.engineLoad != nil, itemLoad.chapter?.relativePath == updatedItem.currentChapter.relativePath {
      observeChapterEnds(inFileOf: updatedItem.currentChapter)
    }
  }

  func initializeChapterTime(_ time: Double) {
    guard let currentItem = self.currentItem else { return }

    let boundedTime = min(max(time, 0), currentItem.duration)

    seekPlayer(to: fileTime(boundedTime, in: currentItem.currentChapter, of: currentItem))
  }

  /// Where `time` in the book falls in `chapter`'s file: a volume's files each start at 0
  private func fileTime(_ time: TimeInterval, in chapter: PlayableChapter, of item: PlayableItem) -> TimeInterval {
    item.isBoundBook ? item.getChapterTime(in: chapter, for: time) : time
  }

  /// Watches the ends of the chapters in `chapter`'s file, which just reached the player. Its last one
  /// is left out: the file ends there, and `playerDidFinishPlaying` takes it
  private func observeChapterEnds(inFileOf chapter: PlayableChapter) {
    chapterBoundaryObservation = nil

    guard let currentItem else { return }

    let chaptersInFile = currentItem.chapters.filter { $0.relativePath == chapter.relativePath }
    let endingAt = Dictionary(
      chaptersInFile.dropLast().map { (fileTime($0.end, in: $0, of: currentItem), $0) },
      uniquingKeysWith: { _, last in last }
    )

    guard !endingAt.isEmpty else { return }

    /// The engine runs its observers on the main queue
    chapterBoundaryObservation = engine.addBoundaryObserver(at: Array(endingAt.keys)) { [weak self] time in
      guard let ended = endingAt[time] else { return }
      MainActor.assumeIsolated {
        self?.handleChapterEnd(ended)
      }
    }
  }

  /// How far into the next chapter an end-of-chapter pause parks. Exactly on its start is a tie: the
  /// ended chapter's `start + duration` can round past it, so a book rebuilt from the saved time reopens
  /// in the chapter that ended, and a precise seek reads back up to 1 ns early (measured on AAC, MP3,
  /// FLAC, WAV and Opus files). 10 ms clears both and is shorter than any speech sound
  private static let chapterParkLead: TimeInterval = 0.01

  /// With the end-of-chapter timer on, park playback at the next chapter's start as the timer pauses: the
  /// resume then begins at its first word, and Smart Rewind has nothing to rewind into the chapter that
  /// ended (GH #1486)
  private func handleChapterEnd(_ ended: PlayableChapter) {
    guard
      SleepTimer.shared.state == .endOfChapter,
      let currentItem,
      /// AVPlayer reports a crossing when playback starts exactly on a boundary, as after Smart Rewind
      /// back to a chapter's start: only the chapter still playing can end, and re-setting
      /// `currentChapter` would end the re-armed timer at once (the GH #1486 loop)
      currentItem.currentChapter == ended,
      let next = currentItem.nextChapter(after: ended)
    else { return }

    let parked = next.start + Self.chapterParkLead
    updatePlaybackTime(item: currentItem, time: parked)
    /// Its sink posts `.chapterChange`: the timer ends and pauses, in this same turn
    currentItem.currentChapter = next
    /// A default seek can land a few milliseconds early, back inside the chapter that ended, and the
    /// resume would cross its end again
    seekPlayer(to: fileTime(parked, in: next, of: currentItem), precisely: true)
  }

  public func jumpTo(_ time: Double, recordBookmark: Bool = true) {
    guard let currentItem = self.currentItem else { return }

    if recordBookmark {
      self.createOrUpdateAutomaticBookmark(
        at: currentItem.currentTime,
        relativePath: currentItem.relativePath,
        uuid: currentItem.uuid,
        type: .skip
      )
    }

    let boundedTime = min(max(time, 0), currentItem.duration)

    let chapterBeforeSkip = currentItem.currentChapter
    updatePlaybackTime(item: currentItem, time: boundedTime)
    if let chapterAfterSkip = currentItem.getChapter(at: boundedTime),
      chapterBeforeSkip != chapterAfterSkip
    {
      currentItem.currentChapter = chapterAfterSkip
      // If chapters are different, and it's a bound book,
      // load the new chapter
      if currentItem.isBoundBook,
        chapterBeforeSkip?.relativePath != chapterAfterSkip.relativePath
      {
        loadChapterMetadata(chapterAfterSkip)
        return
      }
    }

    let newTime =
      currentItem.isBoundBook
      ? currentItem.getChapterTime(in: currentItem.currentChapter, for: boundedTime)
      : boundedTime
    seekPlayer(to: newTime)
  }

  public func forward() {
    if PlayerManager.isForwardChapterSkip {
      skipToNextChapter()
    } else {
      skip(PlayerManager.forwardInterval)
    }
  }

  public func rewind() {
    if PlayerManager.isRewindChapterSkip {
      skipToPreviousChapter()
    } else {
      skip(-PlayerManager.rewindInterval)
    }
  }

  public func skipToNextChapter() {
    if let currentChapter = currentItem?.currentChapter,
      let nextChapter = currentItem?.nextChapter(after: currentChapter)
    {
      jumpToChapter(nextChapter)
    } else {
      playNextItem(autoPlayed: false, shouldAutoplay: true)
    }
    NotificationCenter.default.post(name: .listeningProgressChanged, object: nil)
  }

  public func skipToPreviousChapter() {
    defer { NotificationCenter.default.post(name: .listeningProgressChanged, object: nil) }

    guard let currentItem,
      let currentChapter = currentItem.currentChapter
    else {
      playPreviousItem()
      return
    }

    if !currentItem.isNearChapterStart {
      /// First press while into the chapter goes back to its start
      jumpToChapter(currentChapter)
    } else if let previousChapter = currentItem.previousChapter(before: currentChapter) {
      /// Already near the chapter start, so step back to the previous chapter
      jumpToChapter(previousChapter)
    } else {
      playPreviousItem()
    }
  }

  public func skip(_ interval: TimeInterval) {
    guard let currentItem = self.currentItem else { return }

    let newTime = currentItem.getInterval(from: interval) + currentItem.currentTime
    self.jumpTo(newTime)
  }

  /// Bypass checks on chapter limits
  public func directSkip(_ interval: TimeInterval) {
    guard let currentItem = self.currentItem else { return }

    self.jumpTo(interval + currentItem.currentTime)
  }
}

// MARK: - Playback

extension PlayerManager {
  func prepareForPlayback(_ currentItem: PlayableItem, origin: PlayOrigin) async -> Bool {
    /// A play asked for gets its reloads again
    retryBudget = RetryBudget()

    let isThisFile = itemLoad.chapter?.relativePath == currentItem.currentChapter.relativePath

    switch itemLoad {
    case .empty, .failed:
      load(reloadable(currentItem), intent: .wantsToPlay(origin))
      return false
    case .resolving, .loading:
      if isThisFile {
        /// Play when it's ready, rather than starting over
        playIntent = .wantsToPlay(origin)
      } else {
        loadChapterMetadata(currentItem.currentChapter, intent: .wantsToPlay(origin))
      }
      return false
    case .ready:
      /// The chapter moved to another file without loading it (re-parsed chapters): the item is the
      /// previous file's, and playing it would save its time against the new chapter
      guard isThisFile else {
        loadChapterMetadata(currentItem.currentChapter, intent: .wantsToPlay(origin))
        return false
      }
      /// A stream can fail after it was ready: load it again
      guard !engine.itemHasFailed else {
        load(reloadable(currentItem), intent: .wantsToPlay(origin))
        return false
      }
    }

    /// Update nowPlaying state so the UI displays correctly
    playIntent = .wantsToPlay(origin)
    await syncProgressDelegate?.waitForSyncInProgress()

    return true
  }

  /// `item` rebuilt from the library when it plays from a media server: loading it again after
  /// a failure must use the connection as it's saved now (signed in again, or the missing
  /// server added since the alert said so), not the token and host it was built with.
  private func reloadable(_ item: PlayableItem) -> PlayableItem {
    guard
      item.chapters.contains(where: { $0.isStreamed || $0.hasUnresolvedExternalHost }),
      let libraryItem = libraryService.getSimpleItem(with: item.relativePath),
      let rebuilt = try? playbackService.getPlayableItem(from: libraryItem)
    else { return item }

    cachedStreamFiles = nil
    return rebuilt
  }

  public func play() {
    play(origin: .user)
  }

  /// Take over the system Now Playing slot for CarPlay. iOS only designates the Now Playing app from
  /// one that *actually plays* (a third-party app can't fake `playbackState` — that's an Apple-private
  /// entitlement), so we briefly play **muted**, then pause the instant playback starts — landing on
  /// our book paused, now owning Now Playing, with no audible blip. Skips if nothing is loaded or we're
  /// already playing (we'd own it). A timeout fallback guarantees we unmute even if playback never starts.
  ///
  /// Note: this *will* interrupt audio another app is actively playing. There's no reliable way to detect
  /// that beforehand here — `isOtherAudioPlaying` / `secondaryAudioShouldBeSilencedHint` only update once
  /// our own session is active (the very act we're trying to avoid), and read stale (false) on a CarPlay
  /// background launch. So we accept the takeover as a known side effect.
  ///
  /// Accepted edge: if the user taps play during the brief muted window, our `.first()` captures that
  /// `.playing` and pauses it — they'd tap again. Distinguishing their play from ours on the shared
  /// player isn't reliable, and the window is short, so we accept it. Returns whether attempted.
  @discardableResult
  public func claimNowPlayingThenPause() -> Bool {
    /// `nowPlayingClaimSubscription == nil` gates re-entrancy: a claim stays "in flight" (subscription
    /// non-nil) until its unmute completes below, so a second blip can't start mid-claim and get unmuted
    /// by this one's timer.
    guard currentItem != nil, !isPlaying, nowPlayingClaimSubscription == nil else { return false }

    engine.isMuted = true
    nowPlayingClaimSubscription = engine.statusPublisher
      .filter { $0 == .playing }
      .first()
      // DispatchQueue (not RunLoop) so the timeout still fires while the run loop is in tracking mode
      // (e.g. CarPlay scrolling).
      .timeout(.seconds(3), scheduler: DispatchQueue.main)
      .sink(
        receiveCompletion: { [weak self] _ in
          guard let self else { return }
          /// Pause regardless of how we completed: on success this is the intended pause; on **timeout**
          /// it cancels the still-pending `play()` (which re-checks `Task.isCancelled` after the async
          /// `prepareForPlayback`), so a slow/streaming load can't end up playing aloud and un-paused.
          self.pause()
          /// Unmute only after the pause settles — `timeControlStatus` reaches `.paused` asynchronously,
          /// so unmuting on the same tick can leak a few ms of audio (same reason `bindPauseObserver`
          /// delays). Clear the subscription here (not earlier), so the re-entrancy guard keeps blocking
          /// a new claim until we're fully done and this timer can't unmute someone else's blip.
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            self.engine.isMuted = false
            self.nowPlayingClaimSubscription = nil
          }
        },
        receiveValue: { [weak self] _ in
          /// We actually became the Now Playing app — re-publish the cover, whose async load can finish
          /// before we own the slot (so its push is ignored) and is never re-pushed otherwise.
          guard let self, let chapter = self.currentItem?.currentChapter else { return }
          self.setNowPlayingArtwork(chapter: chapter)
        }
      )

    play(origin: .system)
    return true
  }

  public func play(origin: PlayOrigin) {
    playTask?.cancel()
    playTask = Task {
      /// Ignore play commands if there's no item loaded,
      /// and only continue if the item is loaded and ready
      guard
        let currentItem,
        await prepareForPlayback(currentItem, origin: origin),
        !Task.isCancelled
      else { return }

      userActivityManager.resumePlaybackActivity()

      guard await platform.activateAudioSession(for: currentItem, origin: origin) else {
        playIntent = .idle
        return
      }
      /// A platform can suspend while it activates (the watch's route picker): a pause in the meantime wins,
      /// and ends the session the activation turned on after the pause's own deactivation ran
      guard !Task.isCancelled else {
        platform.deactivateAudioSession()
        return
      }

      createOrUpdateAutomaticBookmark(
        at: currentItem.currentTime,
        relativePath: currentItem.relativePath,
        uuid: currentItem.uuid,
        type: .play
      )

      /// A finished book still loaded: the user's play starts it over from the first chapter, while one
      /// the system makes stops at the end
      let playerTime = engine.currentTime
      if playerTime.isFinite && Int(currentItem.duration) == Int(playerTime) {
        guard origin == .user, let firstChapter = currentItem.chapters.first else {
          playIntent = .idle
          return
        }
        updatePlaybackTime(item: currentItem, time: 0)
        currentItem.currentChapter = firstChapter
        loadChapterMetadata(firstChapter, intent: .wantsToPlay(.user))
        return
      }

      restorePlayerTimeIfNeeded()

      // Skip smart rewind during SharePlay; the seek would drag every participant back
      if !isPlaybackCoordinated {
        handleSmartRewind(currentItem)
      }

      /// Only a play the user asked for arms the remembered timer: a start the system makes
      /// (the next book, the end of an interruption) leaves a running countdown alone
      if origin == .user {
        handleAutoTimer()
      }

      fadeTimer?.invalidate()
      platform.stopShakeDetection()
      boostVolume = UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled)
      bindInterruptObserver()
      // Set play state on player and control center
      engine.play(atRate: currentSpeed)
      /// Clean up flag after player starts playing
      playIntent = .idle

      setNowPlayingBookTitle(chapter: currentItem.currentChapter)

      NotificationCenter.default.post(name: .bookPlayed, object: nil, userInfo: ["book": currentItem])
    }
  }

  func handleSmartRewind(_ item: PlayableItem) {
    let smartRewindEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.smartRewindEnabled)

    if smartRewindEnabled,
      let lastPlayTime = item.lastPlayDate
    {
      let timePassed = max(Date().timeIntervalSince(lastPlayTime), 0)
      let timePassedLimited = min(timePassed, Constants.SmartRewind.threshold)

      let delta = timePassedLimited / Constants.SmartRewind.threshold
      let baseRewindTime = ease(delta) * getMaxInterval()

      // Always rewind by at least minRewind...
      let rewindTimeMin = max(baseRewindTime, Constants.SmartRewind.minRewind)

      // ...but don't rewind past the beginning of the chapter, or more than the amount of time passed
      let timeInChapter = item.currentTime - item.currentChapter.start
      let rewindTimeLimited = min(rewindTimeMin, timeInChapter, timePassed)

      /// Too little to be worth a seek, as where an end-of-chapter pause parks, 10 ms into the chapter
      guard rewindTimeLimited >= 0.1 else { return }

      /// Rewind from where we know playback is, not the raw player clock (see `PlayerTimeSample`)
      let playerTime = clockState.expectedTime ?? self.engine.currentTime
      let newPlayerTime = max(playerTime - rewindTimeLimited, 0)

      seekPlayer(to: newPlayerTime)
    }

    func getMaxInterval() -> TimeInterval {
      let userSetInterval = UserDefaults.standard.double(forKey: Constants.UserDefaults.smartRewindMaxInterval)
      // The interval may be 0 if the setting has never been changed
      return if userSetInterval > 0 {
        userSetInterval
      } else {
        30.0
      }
    }

    // Quartic ease out, where 0 ≤ delta ≤ 1
    // Increases quickly at first, then levels off closer to 1
    func ease(_ delta: Double) -> Double {
      return 1 - pow(1 - delta, 4)
    }
  }

  func handleAutoTimer() {
    guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoTimerEnabled) else { return }

    SleepTimer.shared.restartTimer()
  }

  public func setSpeed(_ newValue: Float) {
    self.speedService.setSpeed(newValue, relativePath: self.currentItem?.relativePath)
    self.currentSpeed = newValue
    if self.isPlaying {
      self.engine.rate = newValue
    }
  }

  public func setBoostVolume(_ newValue: Bool) {
    self.boostVolume = newValue
  }

  public func pause() {
    pause(removeInterruptObserver: true)
  }

  func pause(removeInterruptObserver: Bool) {
    guard self.currentItem != nil else { return }

    self.userActivityManager.stopPlaybackActivity()

    NotificationCenter.default.post(name: .bookPaused, object: nil)

    bindPauseObserver()
    // Set pause state on player and control center
    engine.pause()
    playIntent = .idle
    playTask?.cancel()
    /// A pause cancels finding a file, and the next play starts over. A file already in the engine
    /// finishes loading silently
    if case .resolving = itemLoad {
      itemLoad = .empty
    }
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
    MPNowPlayingInfoCenter.default().playbackState = .paused
    setNowPlayingBookTime()
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    if removeInterruptObserver {
      interruptionSubscription = nil
    }
  }

  // Toggle play/pause of book
  public func playPause() {
    // Pause player if it's playing
    if self.engine.status == .playing || playIntent != .idle {
      self.pause()
    } else {
      self.play()
    }
  }

  /// Access to the underlying player for rendering video tracks; nil for an engine without one.
  /// Note: the instance can be recreated after a media-services reset, so
  /// consumers should re-attach on view updates rather than caching it.
  public func getAVPlayer() -> AVPlayer? {
    return engine.videoPlayer
  }

  public func stop() {
    stopPlayback()
    clockState = .unknown

    self.currentItem = nil
    MPNowPlayingInfoCenter.default().playbackState = .stopped
  }

  private func stopPlayback() {
    itemLoad = .empty
    playIntent = .idle

    engine.pause()
    playTask?.cancel()

    userActivityManager.stopPlaybackActivity()
    interruptionSubscription = nil
  }

  public func markAsCompleted(_ flag: Bool) {
    guard let currentItem = self.currentItem else { return }

    self.libraryService.markAsFinished(flag: flag, relativePath: currentItem.relativePath)

    if let parentFolderPath = currentItem.parentFolder {
      if platform.defersFolderProgress {
        /// Defer all the folder progress updates until the user opens up the app again
        playbackService.markStaleProgress(folderPath: parentFolderPath)
      } else {
        libraryService.recursiveFolderProgressUpdate(from: parentFolderPath)
      }
    }

    currentItem.isFinished = flag

    NotificationCenter.default.post(name: .bookEnd, object: nil, userInfo: nil)
  }

  public func currentSpeedPublisher() -> AnyPublisher<Float, Never> {
    return $currentSpeed.eraseToAnyPublisher()
  }

  public func playPreviousItem() {
    guard
      let currentItem = self.currentItem,
      let previousBook = self.playbackService.getPlayableItem(
        before: currentItem.relativePath,
        parentFolder: currentItem.parentFolder
      )
    else { return }

    load(previousBook, intent: .wantsToPlay(.user))
  }

  public func playNextItem(autoPlayed: Bool = false, shouldAutoplay: Bool = true) {
    /// If it's autoplayed, check if setting is enabled
    if autoPlayed, !platform.autoplaysNextBook {
      return
    }

    let restartFinished = platform.restartsFinishedBooks

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
      restartFinished
    {
      updatePlaybackTime(item: nextBook, time: 0)
    }

    /// Pressing next at the end of a book is the user's play; the next book after a finished one isn't
    load(nextBook, intent: shouldAutoplay ? .wantsToPlay(autoPlayed ? .system : .user) : .idle)
    libraryService.setLibraryLastBook(with: nextBook.relativePath)
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

    /// Skip items whose type doesn't conform to audiovisual content. A file whose
    /// extension maps to no `UTType` (or has none) is left as-is and played.
    if let fileType = nextBook.fileURL.fileType,
      !fileType.isSubtype(of: .audiovisualContent)
    {
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
    guard
      let nextChapter = self.playbackService.getNextChapter(
        from: currentItem,
        after: chapter
      )
    else { return nil }

    /// Skip chapters whose type doesn't conform to audiovisual content. A file whose
    /// extension maps to no `UTType` (or has none) is left as-is and played.
    if let fileType = nextChapter.fileURL.fileType,
      !fileType.isSubtype(of: .audiovisualContent)
    {
      return getNextPlayableChapter(
        currentItem: currentItem,
        after: nextChapter
      )
    }

    return nextChapter
  }

  /// The engine's item reached its end
  private func playerDidFinishPlaying() {
    guard let currentItem = self.currentItem else { return }

    let endOfChapterActive = SleepTimer.shared.state == .endOfChapter

    if currentItem.chapters.last == currentItem.currentChapter {
      if UserDefaults.standard.bool(
        forKey: currentItem.filename + Constants.UserDefaults.repeatEnabledSuffix
      ) {
        updatePlaybackTime(item: currentItem, time: 0)
        let firstChapter = currentItem.chapters.first!
        currentItem.currentChapter = firstChapter
        loadChapterMetadata(firstChapter, intent: endOfChapterActive ? .idle : .wantsToPlay(.system))
      } else {
        self.libraryService.setLibraryLastBook(with: nil)

        self.markAsCompleted(true)

        /// Arm the review prompt; `ReviewPromptService` evaluates eligibility when consumed
        UserDefaults.standard.set(true, forKey: Constants.UserDefaults.pendingReviewPrompt)

        self.playNextItem(autoPlayed: true, shouldAutoplay: !endOfChapterActive)

        NotificationCenter.default.post(name: .bookEnd, object: nil)
      }
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
      loadChapterMetadata(nextChapter, intent: endOfChapterActive ? .idle : .wantsToPlay(.system))
    }
  }

  /// Update the current item playback time, and checks for difference in progress percentage
  func updatePlaybackTime(item: PlayableItem, time: Float64) {
    let previousPercentage = Int(item.percentCompleted)
    self.playbackService.updatePlaybackTime(item: item, time: time)
    let newPercentage = Int(item.percentCompleted)

    if previousPercentage != newPercentage {
      if let parentFolder = item.parentFolder {
        if platform.defersFolderProgress {
          /// Defer all the folder progress updates until the user opens up the app again
          playbackService.markStaleProgress(folderPath: parentFolder)
        } else {
          libraryService.recursiveFolderProgressUpdate(from: parentFolder)
        }
      }

      widgetReloadService.scheduleWidgetReload(of: .sharedNowPlayingWidget)
    }
  }

  private func loadAndRefreshURL(item: PlayableItem) {
    /// A retry plays only if the failed load was going to, for whoever asked
    load(item, intent: playIntent, forceRefreshURL: true)
  }

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

    engine.rebuild()
    /// The new player has no item: drop the old one's load, which would still read as ready, so the
    /// next play loads it again where it was instead of starting an empty player
    itemLoad = .empty
    clockState = .unknown
  }

  /// Playback may be interrupted by calls. Handle resuming the audio if needed
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
        play(origin: .system)
      }
    @unknown default:
      break
    }
  }
}

// MARK: - BookMarks
extension PlayerManager {
  func createOrUpdateAutomaticBookmark(at time: Double, relativePath: String, uuid: String, type: BookmarkType) {
    /// Clean up old bookmark
    if let bookmark = libraryService.getBookmarks(of: type, relativePath: relativePath)?.first {
      libraryService.deleteBookmark(bookmark)
    }

    guard
      let bookmark = libraryService.createBookmark(at: floor(time), relativePath: relativePath, uuid: uuid, type: type)
    else { return }

    libraryService.addNote(type.getNote() ?? "", bookmark: bookmark)
  }
}

// MARK: - Sleep timer
extension PlayerManager {
  private func handleSleepTimerThresholdEvent() {
    fadeTimer = engine.fadeVolume(from: 1, to: 0, duration: 5)
    bindShakeObserver()
  }

  private func handleSleepTimerEndEvent(_ state: SleepTimerState) {
    pause()

    if state == .endOfChapter {
      bindShakeObserver()
    }
  }

  private func handleSleepTimerTurnedOnEvent() {
    guard let currentItem else { return }

    createOrUpdateAutomaticBookmark(
      at: currentItem.currentTime,
      relativePath: currentItem.relativePath,
      uuid: currentItem.uuid,
      type: .sleep
    )
  }

  private func bindShakeObserver() {
    platform.observeFirstShake { [weak self] in
      SleepTimer.shared.restartTimer()
      self?.play()
    }
  }
}

// MARK: - Group playback coordination

extension PlayerManager {
  private var isPlaybackCoordinated: Bool {
    #if os(iOS)
    return engine.playbackCoordination != nil
    #else
    return false
    #endif
  }

  /// Keep a remote participant's rate in session state, never in the user's saved speed.
  func reconcileGroupPlaybackRate() {
    guard isPlaybackCoordinated else { return }

    let groupRate = engine.rate
    guard groupRate > 0, abs(groupRate - currentSpeed) > 0.01 else { return }

    currentSpeed = groupRate
  }

  #if os(iOS)
  /// App-owned coordination stays outside the shared player core. The engine reapplies it
  /// whenever it replaces its AVPlayer, including after a media-services reset or failure.
  public func setPlaybackCoordination(_ coordination: PlaybackCoordinating?) {
    groupPlaybackSubscription?.cancel()
    groupPlaybackSubscription = nil
    engine.playbackCoordination = coordination
    guard let coordination else { return }

    groupPlaybackSubscription = engine.statusPublisher
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self, weak coordination] status in
        guard let self, let coordination,
          self.engine.playbackCoordination === coordination,
          status != .paused, self.engine.status != .paused
        else { return }

        // A remote resume bypasses play(). Restore its audio state without seeking,
        // changing play intent, or rearming the user's remembered sleep timer.
        self.isPlayingSubscription?.cancel()
        self.isPlayingSubscription = nil
        self.fadeTimer?.invalidate()
        self.platform.stopShakeDetection()
        self.boostVolume = UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled)
        coordination.activateAudioSession()
        self.bindInterruptObserver()
      }
  }
  #endif
}
