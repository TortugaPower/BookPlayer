//
//  PlayerManagerTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 18/5/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation
import MediaPlayer

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class PlayerManagerTests: XCTestCase {
  var playbackServiceMock: PlaybackServiceProtocolMock!
  var libraryServiceMock: LibraryServiceProtocolMock!
  var speedServiceMock: SpeedServiceProtocolMock!
  var syncServiceMock: SyncServiceProtocolMock!
  /// Read live by `sut`'s entitlement closure, so a test can flip the entitlement on `sut`.
  var streamingEnabled = true
  var sut: PlayerManager!
  /// Keeps the in-memory store alive for the playback record `play()` asks the library for.
  private var playbackRecordStack: DataManager?
  private var savedTimerDefaults: [String: Any] = [:]
  private var copiedFixtureURL: URL?

  private let timerDefaultKeys = [
    Constants.UserDefaults.smartRewindEnabled,
    Constants.UserDefaults.smartRewindMaxInterval,
    Constants.UserDefaults.autoTimerEnabled,
    Constants.UserDefaults.lastEnabledTimer,
  ]

  override func setUp() {
    // Clean up stored configs
    UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.chapterContextEnabled)
    UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.remainingTimeEnabled)
    savedTimerDefaults = timerDefaultKeys.reduce(into: [:]) { stored, key in
      stored[key] = UserDefaults.standard.object(forKey: key)
    }

    self.playbackServiceMock = PlaybackServiceProtocolMock()
    /// Mirror production `PlaybackService.updatePlaybackTime(item:time:)`, which advances the
    /// playhead, so seek targets are observable in tests instead of staying frozen.
    self.playbackServiceMock.updatePlaybackTimeItemTimeClosure = { item, time in
      item.currentTime = time
      item.lastPlayDate = Date()
    }
    self.libraryServiceMock = LibraryServiceProtocolMock()
    self.speedServiceMock = SpeedServiceProtocolMock()
    self.speedServiceMock.getSpeedRelativePathReturnValue = 1
    self.syncServiceMock = SyncServiceProtocolMock()
    self.sut = PlayerManager(
      libraryService: libraryServiceMock,
      playbackService: playbackServiceMock,
      syncService: syncServiceMock,
      speedService: speedServiceMock,
      shakeMotionService: ShakeMotionServiceProtocolMock(),
      widgetReloadService: WidgetReloadService(),
      // Entitled by default, so nothing here is suppressed by tier; the item half of the rule
      // is covered by MediaServersShortcutTests against PlayableChapter.
      hasStreamingEnabled: { [weak self] in self?.streamingEnabled ?? true },
      presentFailure: { _ in }
    )
  }

  override func tearDown() {
    sut.stop()
    SleepTimer.shared.setTimer(.off)
    for key in timerDefaultKeys {
      if let value = savedTimerDefaults[key] {
        UserDefaults.standard.set(value, forKey: key)
      } else {
        UserDefaults.standard.removeObject(forKey: key)
      }
    }
    if let copiedFixtureURL {
      try? FileManager.default.removeItem(at: copiedFixtureURL)
    }
    playbackRecordStack = nil
    super.tearDown()
  }

  private func generatePlayableItem() -> PlayableItem {
    let testChapter = PlayableChapter(
      title: "test chapter 1",
      author: "test author chapter",
      start: 0,
      duration: 50,
      relativePath: "",
      remoteURL: nil,
      externalURL: nil,
      index: 0
    )
    let testChapter2 = PlayableChapter(
      title: "test chapter 2",
      author: "test author chapter 2",
      start: 51,
      duration: 100,
      relativePath: "",
      remoteURL: nil,
      externalURL: nil,
      index: 1
    )
    return PlayableItem(
      title: "test book",
      author: "test author",
      chapters: [testChapter, testChapter2],
      currentTime: 0,
      duration: 100,
      relativePath: "",
      uuid: "LEGACY_UUID",
      parentFolder: nil,
      percentCompleted: 10,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
  }

  /// Two-chapter item using production's 1-based chapter indexing, so
  /// `nextChapter`/`previousChapter` navigation resolves correctly.
  private func generateChapteredItem() -> PlayableItem {
    let chapter1 = PlayableChapter(
      title: "chapter 1",
      author: "author",
      start: 0,
      duration: 50,
      relativePath: "",
      remoteURL: nil,
      externalURL: nil,
      index: 1
    )
    let chapter2 = PlayableChapter(
      title: "chapter 2",
      author: "author",
      start: 51,
      duration: 100,
      relativePath: "",
      remoteURL: nil,
      externalURL: nil,
      index: 2
    )
    return PlayableItem(
      title: "test book",
      author: "test author",
      chapters: [chapter1, chapter2],
      currentTime: 0,
      duration: 151,
      relativePath: "",
      uuid: "LEGACY_UUID",
      parentFolder: nil,
      percentCompleted: 10,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
  }

  /// The tier half of the Media Servers shortcut. The item half lives on PlayableChapter
  /// (MediaServersShortcutTests); this pins the wiring — that the entitlement closure is
  /// actually consulted — against a real PlayerManager.
  private func makeUnplayableExternalChapter(
    host: PlayableChapter.UnresolvedHost = .init(provider: .jellyfin, address: nil)
  ) -> PlayableChapter {
    PlayableChapter(
      title: "test chapter",
      author: "test author",
      start: 0,
      duration: 50,
      relativePath: "no-such-file.m4b",
      remoteURL: URL(string: "https://s3.example.com/presigned"),
      externalURL: nil,
      index: 0,
      unresolvedHost: host
    )
  }

  /// An item whose host has no saved connection is a DIFFERENT problem from a server that
  /// won't answer, and only the surfaces can word that difference — so the reason has to be
  /// derived correctly here. Order matters: `needsMediaServer()` is true for both shapes.
  func testAnUnresolvedHostIsAMissingConnectionNotAnUnreachableStream() {
    let failure = sut.playbackFailure(
      for: makeUnplayableExternalChapter(),
      title: "t",
      message: "m"
    )

    XCTAssertEqual(failure.reason, .missingConnection)
    XCTAssertTrue(failure.canOfferMediaServers)
  }

  /// The case the derivation order exists for. `hasUnresolvedExternalHost` is a stored flag
  /// that stays true on a book you already DOWNLOADED from a server you later removed, so
  /// reading it first blamed a missing server for a local file that simply won't open — and
  /// produced a reason that disagreed with `canOfferMediaServers` on the same value.
  func testADownloadedBookIsNeverBlamedOnAMissingServer() throws {
    let relativePath = "downloaded-from-a-removed-server.m4b"
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)
    try Data("not really audio".utf8).write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let chapter = PlayableChapter(
      title: "test chapter",
      author: "test author",
      start: 0,
      duration: 50,
      relativePath: relativePath,
      remoteURL: nil,
      externalURL: nil,
      index: 0,
      unresolvedHost: .init(provider: .audiobookshelf, address: "https://abs.example.com")
    )

    let failure = sut.playbackFailure(for: chapter, title: "t", message: "m")

    XCTAssertEqual(failure.reason, .other, "the file is on disk — no server is involved")
    XCTAssertEqual(failure.phoneMessage, "m", "only a missing connection names the server")
    XCTAssertFalse(
      failure.canOfferMediaServers,
      "reason and the shortcut must not disagree on the same failure"
    )
  }

  func testAResolvedStreamThatFailedIsUnavailableNotMissing() {
    let chapter = PlayableChapter(
      title: "test chapter",
      author: "test author",
      start: 0,
      duration: 50,
      relativePath: "no-such-file.m4b",
      remoteURL: nil,
      externalURL: URL(string: "https://jellyfin.example.com/stream"),
      index: 0
    )

    XCTAssertEqual(
      sut.playbackFailure(for: chapter, title: "t", message: "m").reason,
      .streamUnavailable
    )
  }

  /// No chapter at all (the player item failed before one was resolved) must not claim a
  /// media-server problem, or the surfaces offer a fix for something else entirely.
  func testAFailureWithNoChapterOffersNothing() {
    let failure = sut.playbackFailure(for: nil, title: "t", message: nil)

    XCTAssertEqual(failure.reason, .other)
    XCTAssertFalse(failure.canOfferMediaServers)
  }

  /// A server the item names by address can be named back to the user, so they know which one
  /// to add.
  func testAMissingConnectionWithAnAddressNamesTheServer() {
    let failure = sut.playbackFailure(
      for: makeUnplayableExternalChapter(
        host: .init(provider: .audiobookshelf, address: "https://abs.example.com")
      ),
      title: "t",
      message: "m"
    )

    XCTAssertEqual(failure.reason, .missingConnection)
    XCTAssertEqual(
      failure.phoneMessage,
      String(
        format: "integration_error_missing_connection_address".localized,
        "Audiobookshelf",
        "https://abs.example.com"
      )
    )
    XCTAssertTrue(failure.phoneMessage?.contains("https://abs.example.com") ?? false)
  }

  /// An id-shaped host (a Jellyfin GUID, a legacy `server-settings`) has no address to show,
  /// so the phone keeps its usual copy.
  func testAMissingConnectionWithoutAnAddressKeepsTheMessage() {
    let failure = sut.playbackFailure(
      for: makeUnplayableExternalChapter(host: .init(provider: .jellyfin, address: nil)),
      title: "t",
      message: "m"
    )

    XCTAssertEqual(failure.reason, .missingConnection)
    XCTAssertEqual(failure.phoneMessage, "m")
  }

  /// The phone's copy is deliberately passed through untouched — the error code and NSError
  /// dump are worth keeping for support threads.
  func testThePhoneCopyIsCarriedVerbatim() {
    let failure = sut.playbackFailure(for: nil, title: "Error 1234", message: "userInfo={...}")

    XCTAssertEqual(failure.phoneTitle, "Error 1234")
    XCTAssertEqual(failure.phoneMessage, "userInfo={...}")
  }

  func testMediaServersShortcutOfferedWhenStreamingIsEnabled() {
    XCTAssertTrue(self.sut.offersMediaServers(for: makeUnplayableExternalChapter()))
  }

  func testMediaServersShortcutSuppressedWithoutStreaming() {
    let unentitled = PlayerManager(
      libraryService: LibraryServiceProtocolMock(),
      playbackService: playbackServiceMock,
      syncService: SyncServiceProtocolMock(),
      speedService: SpeedServiceProtocolMock(),
      shakeMotionService: ShakeMotionServiceProtocolMock(),
      widgetReloadService: WidgetReloadService(),
      hasStreamingEnabled: { false },
      presentFailure: { _ in }
    )

    XCTAssertFalse(
      unentitled.offersMediaServers(for: makeUnplayableExternalChapter()),
      "a tier that can't stream has nothing to gain from the shortcut"
    )
  }

  // MARK: - AudiobookShelf file lookups

  private let absServer = URL(string: "https://abs.example.com")!

  private func makeStreamingManager(
    lookup: ExternalStreamLooking,
    presentFailure: @escaping (PlaybackFailure) -> Void = { _ in }
  ) -> PlayerManager {
    // No cloud copy to fall back on
    let syncService = SyncServiceProtocolMock()
    syncService.isActive = false

    return PlayerManager(
      libraryService: LibraryServiceProtocolMock(),
      playbackService: playbackServiceMock,
      syncService: syncService,
      speedService: SpeedServiceProtocolMock(),
      shakeMotionService: ShakeMotionServiceProtocolMock(),
      widgetReloadService: WidgetReloadService(),
      hasStreamingEnabled: { true },
      presentFailure: presentFailure,
      streamLookup: lookup
    )
  }

  /// End to end through the load: nothing serves the chapter (its server is away, and there's
  /// no cloud copy), and the play the user started says so in the app's words.
  @MainActor
  func testAChapterNothingServesSaysItsServerDidnt() async {
    let presented = expectation(description: "the failure is presented")
    var failure: PlaybackFailure?
    let manager = makeStreamingManager(lookup: LookupStub(answer: .unreachable)) {
      failure = $0
      presented.fulfill()
    }

    manager.loadChapterMetadata(streamedChapter(.item), autoplay: true)
    await fulfillment(of: [presented], timeout: 5)

    XCTAssertEqual(failure?.reason, .streamUnavailable)
    XCTAssertEqual(failure?.phoneMessage, "playback_error_server_unavailable".localized)
  }

  /// The last book, preloaded at launch: its failure waits for a tap to be said.
  @MainActor
  func testASilentLoadThatFailsStaysQuiet() async {
    let presented = expectation(description: "no alert")
    presented.isInverted = true
    let lookup = LookupStub(answer: .sessionExpired)
    let manager = makeStreamingManager(lookup: lookup) { _ in presented.fulfill() }

    manager.loadChapterMetadata(streamedChapter(.item), autoplay: false)
    await fulfillment(of: [presented], timeout: 0.5)

    XCTAssertEqual(lookup.calls, 1, "the load ran")
  }

  private func streamedChapter(_ member: PlayableChapter.StreamLookup.Member, externalURL: URL? = nil) -> PlayableChapter {
    PlayableChapter(
      title: "test chapter",
      author: "test author",
      start: 0,
      duration: 50,
      relativePath: "no-such-file.mp3",
      remoteURL: nil,
      externalURL: externalURL,
      index: 0,
      externalHeaders: ["Authorization": "Bearer t"],
      streamLookup: externalURL == nil
        ? PlayableChapter.StreamLookup(serverURL: absServer, itemId: "li_1", member: member)
        : nil
    )
  }

  private let twoFiles = [
    ExternalStreamFile(path: "api/items/li_1/file/1", name: "01.mp3", duration: 25),
    ExternalStreamFile(path: "api/items/li_1/file/2", name: "02.mp3", duration: 25),
  ]

  /// One lookup per item, not per book; a forced refresh (the retry after a failed stream)
  /// asks again, since the file may have been replaced.
  @MainActor
  func testAVolumesBooksShareOneLookup() async throws {
    let lookup = LookupStub(answer: .answered(twoFiles))
    let manager = makeStreamingManager(lookup: lookup)

    let first = try await manager.streamURL(for: streamedChapter(.volumeBook(fileName: "01.mp3", position: 0, bookCount: 2)), forceRefresh: false)
    let second = try await manager.streamURL(for: streamedChapter(.volumeBook(fileName: "02.mp3", position: 1, bookCount: 2)), forceRefresh: false)

    XCTAssertEqual(first, .success(URL(string: "https://abs.example.com/api/items/li_1/file/1")!))
    XCTAssertEqual(second, .success(URL(string: "https://abs.example.com/api/items/li_1/file/2")!))
    XCTAssertEqual(lookup.calls, 1)
    XCTAssertEqual(lookup.timeouts, [ExternalStreamLookupTimeout.playback])

    _ = try await manager.streamURL(for: streamedChapter(.volumeBook(fileName: "01.mp3", position: 0, bookCount: 2)), forceRefresh: true)
    XCTAssertEqual(lookup.calls, 2)
  }

  /// A volume played away from home: its next files go straight to the cloud copy instead of
  /// waiting out the timeout again, for a while.
  @MainActor
  func testAFailedLookupIsReusedForTheItemsOtherFiles() async throws {
    let lookup = LookupStub(answer: .unreachable)
    let manager = makeStreamingManager(lookup: lookup)

    _ = try await manager.streamURL(for: streamedChapter(.volumeBook(fileName: "01.mp3", position: 0, bookCount: 2)), forceRefresh: false)
    let second = try await manager.streamURL(for: streamedChapter(.volumeBook(fileName: "02.mp3", position: 1, bookCount: 2)), forceRefresh: false)

    XCTAssertEqual(second, .failure(.unavailable))
    XCTAssertEqual(lookup.calls, 1)
  }

  /// Jellyfin's URL is known up front: nothing to ask.
  @MainActor
  func testAJellyfinURLNeedsNoLookup() async throws {
    let lookup = LookupStub(answer: .answered([]))
    let url = URL(string: "https://jelly.example.com/stream")!

    let result = try await makeStreamingManager(lookup: lookup).streamURL(for: streamedChapter(.item, externalURL: url), forceRefresh: false)

    XCTAssertEqual(result, .success(url))
    XCTAssertEqual(lookup.calls, 0)
  }

  @MainActor
  func testALookupThatDoesntServeTheBookSaysWhy() async throws {
    let cases: [(ExternalStreamFiles, Result<URL, PlayerManager.StreamFailure>)] = [
      (.sessionExpired, .failure(.sessionExpired)),
      (.unreachable, .failure(.unavailable)),
      (.failed, .failure(.unavailable)),
      // A multi-file item imported as one book: no file of its own
      (.answered(twoFiles), .failure(.unavailable)),
      (.answered([]), .failure(.unavailable)),
    ]

    for (answer, expected) in cases {
      let result = try await makeStreamingManager(lookup: LookupStub(answer: answer))
        .streamURL(for: streamedChapter(.item), forceRefresh: false)
      XCTAssertEqual(result, expected, "\(answer)")
    }
  }

  /// A rejected token is its own failure: signing in again in Media Servers fixes it.
  func testAnExpiredSessionSaysToSignInAgain() {
    let failure = sut.playbackFailure(for: streamedChapter(.item), title: "t", message: nil, streamFailure: .sessionExpired)

    XCTAssertEqual(failure.reason, .sessionExpired)
    XCTAssertEqual(failure.phoneMessage, "playback_error_session_expired".localized)
    XCTAssertTrue(failure.canOfferMediaServers)
    XCTAssertEqual(failure.carPlayMessage, "carplay_session_expired_message".localized)
  }

  /// Its server was asked and didn't serve it, and nothing else could: there's no AVFoundation
  /// error to show, so the phone says what happened.
  func testAServerThatDidntServeTheBookSaysSo() {
    let failure = sut.playbackFailure(for: streamedChapter(.item), title: "t", message: nil, streamFailure: .unavailable)

    XCTAssertEqual(failure.reason, .streamUnavailable)
    XCTAssertEqual(failure.phoneMessage, "playback_error_server_unavailable".localized)
    XCTAssertTrue(failure.canOfferMediaServers)
  }

  /// Naming the server is advice to add it, and a tier that can't stream gains nothing from
  /// that: the phone keeps its usual copy, as the car does.
  func testAMissingConnectionIsNotNamedWithoutStreaming() {
    let unentitled = PlayerManager(
      libraryService: LibraryServiceProtocolMock(),
      playbackService: playbackServiceMock,
      syncService: SyncServiceProtocolMock(),
      speedService: SpeedServiceProtocolMock(),
      shakeMotionService: ShakeMotionServiceProtocolMock(),
      widgetReloadService: WidgetReloadService(),
      hasStreamingEnabled: { false },
      presentFailure: { _ in }
    )

    let failure = unentitled.playbackFailure(
      for: makeUnplayableExternalChapter(
        host: .init(provider: .audiobookshelf, address: "https://abs.example.com")
      ),
      title: "t",
      message: "m"
    )

    XCTAssertEqual(failure.reason, .missingConnection)
    XCTAssertEqual(failure.phoneMessage, "m")
  }

  /// The gate that makes the entitlement enforceable at all: before it, the external branch
  /// had no check, so a row that outlived its subscription kept streaming.
  ///
  /// `syncService.isActive` is forced true only to make the diversion observable — in
  /// production it implies an active pro/lite, which implies streaming access, so the two can
  /// never disagree this way. What is being pinned is that the external branch is skipped.
  @MainActor
  func testAnUnentitledUserDoesNotStreamAnExternalChapter() async throws {
    streamingEnabled = false
    syncServiceMock.isActive = true
    // Fail the presign through the CLOSURE, not `ThrowableError`: the generated mock throws
    // before it increments its call count, which would make the assertion below unfalsifiable.
    // `RemoteFileURL` is decode-only, so returning a stub response isn't an option.
    syncServiceMock.getRemoteFileURLsOfForTypeClosure = { _, _, _ in
      throw BookPlayerError.cancelledTask
    }
    let chapter = PlayableChapter(
      title: "test chapter",
      author: "test author",
      start: 0,
      duration: 100,
      relativePath: "no-such-file.m4b",
      remoteURL: nil,
      externalURL: URL(string: "https://jelly.example.com/stream"),
      index: 1
    )

    _ = try? await sut.loadPlayerItem(for: chapter, forceRefreshURL: false)

    XCTAssertEqual(
      syncServiceMock.getRemoteFileURLsOfForTypeCallsCount,
      1,
      "without streaming access the external branch is skipped, so the load falls through it"
    )
  }

  /// Branch order in `loadPlayerItem`: a media-server chapter streams from its own URL even
  /// when the caller forces a refresh. Inverting the external and cloud branches would send
  /// a Jellyfin/ABS book to the S3 presign endpoint, which has nothing to hand back for it.
  @MainActor
  func testForcedRefreshKeepsAnExternalChapterOnItsStreamURL() async throws {
    syncServiceMock.isActive = true
    let chapter = PlayableChapter(
      title: "test chapter",
      author: "test author",
      start: 0,
      duration: 100,
      relativePath: "no-such-file.m4b",
      remoteURL: URL(string: "https://s3.example.com/presigned"),
      externalURL: URL(string: "https://jelly.example.com/stream"),
      index: 1
    )

    _ = try await sut.loadPlayerItem(for: chapter, forceRefreshURL: true)

    XCTAssertEqual(
      syncServiceMock.getRemoteFileURLsOfForTypeCallsCount,
      0,
      "the cloud presign path must never be consulted for a chapter that has a stream URL"
    )
  }

  func testUpdatingEmptyNowPlayingBookTime() {
    self.sut.setNowPlayingBookTime()

    XCTAssertNil(self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate])
    XCTAssertNil(self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime])
    XCTAssertNil(self.sut.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration])
    XCTAssertNil(self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress])
  }

  func testUpdatingGlobalNowPlayingBookTime() {
    // playback speed shouldn't affect duration time set
    self.sut.setSpeed(2)
    // mocked playable item
    let playableItem = generatePlayableItem()
    playableItem.currentTime = 20

    self.sut.currentItem = playableItem
    self.sut.setNowPlayingBookTime()

    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double) == 1)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double) == 20)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double) == 100)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] as? Double) == 0.2)
  }

  func testUpdatingGlobalRemainingNowPlayingBookTime() {
    // playback speed should affect duration time set
    self.sut.setSpeed(2)
    UserDefaults.sharedDefaults.set(true, forKey: Constants.UserDefaults.remainingTimeEnabled)
    // mocked playable item
    let playableItem = generatePlayableItem()
    playableItem.currentTime = 20

    self.sut.currentItem = playableItem
    self.sut.setNowPlayingBookTime()

    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double) == 1)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double) == 20)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double) == 60)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] as? Double) == 0.2)
  }

  func testUpdatingChapterNowPlayingBookTime() {
    // playback speed shouldn't affect duration time set
    self.sut.setSpeed(2)
    UserDefaults.sharedDefaults.set(true, forKey: Constants.UserDefaults.chapterContextEnabled)
    // mocked playable item
    let playableItem = generatePlayableItem()
    playableItem.currentTime = 10

    self.sut.currentItem = playableItem
    self.sut.setNowPlayingBookTime()

    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double) == 1)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double) == 10)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double) == 50)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] as? Double) == 0.20)
  }

  func testUpdatingChapterRemainingNowPlayingBookTime() {
    // playback speed should affect duration time set
    self.sut.setSpeed(2)
    UserDefaults.sharedDefaults.set(true, forKey: Constants.UserDefaults.remainingTimeEnabled)
    UserDefaults.sharedDefaults.set(true, forKey: Constants.UserDefaults.chapterContextEnabled)
    // mocked playable item
    let playableItem = generatePlayableItem()
    playableItem.currentTime = 10

    self.sut.currentItem = playableItem
    self.sut.setNowPlayingBookTime()

    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double) == 1)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double) == 10)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double) == 30)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] as? Double) == 0.20)
  }

  func testUpdatingEmptyNowPlayingBookTitle() {
    let playableItem = generatePlayableItem()
    let chapter = playableItem.chapters.first!

    self.sut.setNowPlayingBookTitle(chapter: chapter)

    XCTAssertNil(self.sut.nowPlayingInfo[MPMediaItemPropertyTitle])
    XCTAssertNil(self.sut.nowPlayingInfo[MPMediaItemPropertyArtist])
    XCTAssertNil(self.sut.nowPlayingInfo[MPMediaItemPropertyAlbumTitle])
  }

  func testUpdatingNowPlayingBookTitle() {
    let playableItem = generatePlayableItem()
    let chapter = playableItem.chapters.first!

    self.sut.currentItem = playableItem
    self.sut.setNowPlayingBookTitle(chapter: chapter)

    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyTitle] as? String) == chapter.title)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyArtist] as? String) == playableItem.title)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyAlbumTitle] as? String) == playableItem.author)
  }

  func testGetNextPlayableBookSuccess() {
    playbackServiceMock.getPlayableItemAfterParentFolderAutoplayedRestartFinishedReturnValue = PlayableItem.mockWithExtension("mp3")

    let nextItem = sut.getNextPlayableBook(
      after: PlayableItem.mock,
      autoPlayed: true,
      restartFinished: true
    )

    XCTAssertNotNil(nextItem)
    XCTAssertTrue(playbackServiceMock.getPlayableItemAfterParentFolderAutoplayedRestartFinishedCallsCount == 1)
  }

  func testGetNextPlayableBookJpgFail() {
    /// Test unrecognized file
    playbackServiceMock
      .getPlayableItemAfterParentFolderAutoplayedRestartFinishedClosure = { relativePath, _, _, _ in
        return [PlayableItem.mockWithExtension("jpg")].filter({ $0.relativePath != relativePath }).first
      }

    let nextItem = sut.getNextPlayableBook(
      after: PlayableItem.mock,
      autoPlayed: true,
      restartFinished: true
    )

    XCTAssertNil(nextItem)
    XCTAssertTrue(playbackServiceMock.getPlayableItemAfterParentFolderAutoplayedRestartFinishedCallsCount == 2)
  }

  // MARK: - skipToPreviousChapter

  func testSkipToPreviousChapterMidChapterRestartsCurrentChapter() {
    let item = generateChapteredItem()
    item.currentChapter = item.chapters[1]  // chapter 2, starts at 51
    item.currentTime = 100  // well past the start threshold
    sut.currentItem = item

    sut.skipToPreviousChapter()

    // Restarts the current chapter (seeks to its start) rather than stepping back
    XCTAssertEqual(sut.currentItem?.currentChapter?.index, 2)
    XCTAssertEqual(sut.currentItem?.currentTime ?? 0, 51.1, accuracy: 0.0001)
    XCTAssertEqual(playbackServiceMock.getPlayableItemBeforeParentFolderCallsCount, 0)
  }

  func testSkipToPreviousChapterNearStartStepsToPreviousChapter() {
    let item = generateChapteredItem()
    item.currentChapter = item.chapters[1]  // chapter 2, starts at 51
    item.currentTime = 52  // within the start threshold
    sut.currentItem = item

    sut.skipToPreviousChapter()

    // Steps back to the previous chapter's start
    XCTAssertEqual(sut.currentItem?.currentChapter?.index, 1)
    XCTAssertEqual(sut.currentItem?.currentTime ?? -1, 0.1, accuracy: 0.0001)
    XCTAssertEqual(playbackServiceMock.getPlayableItemBeforeParentFolderCallsCount, 0)
  }

  func testSkipToPreviousChapterFirstChapterMidChapterRestartsInstead() {
    let item = generateChapteredItem()
    item.currentChapter = item.chapters[0]  // chapter 1, starts at 0
    item.currentTime = 30  // mid-chapter, past the threshold
    sut.currentItem = item

    sut.skipToPreviousChapter()

    // Restarts chapter 1 (seeks to its start) instead of jumping to the previous item
    XCTAssertEqual(sut.currentItem?.currentChapter?.index, 1)
    XCTAssertEqual(sut.currentItem?.currentTime ?? -1, 0.1, accuracy: 0.0001)
    XCTAssertEqual(playbackServiceMock.getPlayableItemBeforeParentFolderCallsCount, 0)
  }

  func testSkipToPreviousChapterFirstChapterNearStartPlaysPreviousItem() {
    let item = generateChapteredItem()
    item.currentChapter = item.chapters[0]  // chapter 1, starts at 0
    item.currentTime = 1  // within the start threshold, no previous chapter
    sut.currentItem = item

    sut.skipToPreviousChapter()

    // Falls back to the previous item without seeking within the current one
    XCTAssertEqual(playbackServiceMock.getPlayableItemBeforeParentFolderCallsCount, 1)
    XCTAssertEqual(sut.currentItem?.currentTime ?? -1, 1, accuracy: 0.0001)
  }

  // MARK: - Smart Rewind at a chapter boundary

  func testSmartRewindTargetStaysInTheCurrentChapter() throws {
    let overnight: TimeInterval = 12 * 60 * 60
    let maxInterval: TimeInterval = 30

    let fractionalTarget = try XCTUnwrap(
      PlayerManager.smartRewindSeekTarget(
        playerTime: 10.4,
        chapterElapsed: 0.4,
        chapterFileStart: 10,
        timePassed: overnight,
        maxInterval: maxInterval
      )
    )
    XCTAssertEqual(fractionalTarget.time, 10, accuracy: 0.000_001)
    XCTAssertTrue(fractionalTarget.pinsChapterStart)
    XCTAssertEqual(chapteredBook().getChapter(at: fractionalTarget.time)?.index, 2)

    let exact = PlayerManager.smartRewindSeekTarget(
      playerTime: 10,
      chapterElapsed: 0,
      chapterFileStart: 10,
      timePassed: overnight,
      maxInterval: maxInterval
    )
    XCTAssertNil(exact, "already on the chapter start — seeking would let tolerance step backward")

    // Model is further into the chapter than the player. Subtracting the model elapsed from the
    // player clock used to land before this chapter's start.
    let mismatched = PlayerManager.smartRewindSeekTarget(
      playerTime: 10.05,
      chapterElapsed: 2,
      chapterFileStart: 10,
      timePassed: overnight,
      maxInterval: maxInterval
    )
    XCTAssertEqual(mismatched?.time ?? -1, 10, accuracy: 0.000_001)
    XCTAssertGreaterThanOrEqual(mismatched?.time ?? -1, 10)

    // `playerTime - elapsed` undershoots the boundary. The target has to be this chapter's start.
    let undershoot = PlayerManager.smartRewindSeekTarget(
      playerTime: 10.2,
      chapterElapsed: 0.2 + 0.000_000_001,
      chapterFileStart: 10,
      timePassed: overnight,
      maxInterval: maxInterval
    )
    XCTAssertEqual(undershoot?.time ?? -1, 10, accuracy: 0)
    XCTAssertEqual(chapteredBook().getChapter(at: undershoot?.time ?? -1)?.index, 2)

    // A negative elapsed must not be subtracted (that seeks forward by its magnitude).
    let negative = PlayerManager.smartRewindSeekTarget(
      playerTime: 10.2,
      chapterElapsed: -1.5,
      chapterFileStart: 10,
      timePassed: overnight,
      maxInterval: maxInterval
    )
    XCTAssertNil(negative)

    let negativeAndBehind = PlayerManager.smartRewindSeekTarget(
      playerTime: 9.4,
      chapterElapsed: -2,
      chapterFileStart: 10,
      timePassed: overnight,
      maxInterval: maxInterval
    )
    XCTAssertEqual(negativeAndBehind?.time ?? -1, 10, accuracy: 0.000_001)
    XCTAssertLessThan(negativeAndBehind?.time ?? 0, 10.2)

    // Chapter inside a bound file: floor is the file offset, not 0 and not the global start.
    let withinFile = PlayerManager.smartRewindSeekTarget(
      playerTime: 150.2,
      chapterElapsed: 0.2,
      chapterFileStart: 150,
      timePassed: overnight,
      maxInterval: maxInterval
    )
    XCTAssertEqual(withinFile?.time ?? -1, 150, accuracy: 0.000_001)
    XCTAssertEqual(withinFile?.pinsChapterStart, true)

    // First chapter of a new file: offset is 0, so the floor is the file start.
    let newFile = PlayerManager.smartRewindSeekTarget(
      playerTime: 0.3,
      chapterElapsed: 0.3,
      chapterFileStart: 0,
      timePassed: overnight,
      maxInterval: maxInterval
    )
    XCTAssertEqual(newFile?.time ?? -1, 0, accuracy: 0.000_001)

    let midChapter = PlayerManager.smartRewindSeekTarget(
      playerTime: 25,
      chapterElapsed: 25,
      chapterFileStart: 0,
      timePassed: overnight,
      maxInterval: 10
    )
    XCTAssertEqual(midChapter?.time ?? -1, 15, accuracy: 0.000_001)
    XCTAssertEqual(midChapter?.pinsChapterStart, false)

    let justResumed = PlayerManager.smartRewindSeekTarget(
      playerTime: 18,
      chapterElapsed: 8,
      chapterFileStart: 10,
      timePassed: 0,
      maxInterval: maxInterval
    )
    XCTAssertNil(justResumed)
  }

  func testChapterFileStartMatchesThePlayerTimeline() {
    let single = chapteredBook()
    single.currentChapter = single.chapters[1]
    XCTAssertEqual(PlayerManager.chapterFileStart(for: single), 10)

    let bound = chapteredBook(bound: true, chapterOffset: 150, globalStart: 5_000)
    bound.currentChapter = bound.chapters[1]
    XCTAssertEqual(PlayerManager.chapterFileStart(for: bound), 150)

    let newFile = chapteredBook(bound: true, chapterOffset: 0, globalStart: 5_000)
    newFile.currentChapter = newFile.chapters[1]
    XCTAssertEqual(PlayerManager.chapterFileStart(for: newFile), 0)
  }

  @MainActor
  func testHandleSmartRewindDoesNotSeekBeforeTheChapter() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    UserDefaults.standard.set(30.0, forKey: Constants.UserDefaults.smartRewindMaxInterval)
    let item = try await loadWellFormedBook(at: 10.05)
    item.lastPlayDate = Date().addingTimeInterval(-12 * 60 * 60)
    item.currentTime = 12

    await sut.handleSmartRewind(item)

    let fileTime = CMTimeGetSeconds(sut.getAVPlayer().currentTime())
    XCTAssertGreaterThanOrEqual(fileTime, 10)
    XCTAssertEqual(item.getChapter(at: fileTime)?.index, 2)
    XCTAssertEqual(item.currentChapter.index, 2)
  }

  @MainActor
  func testMidChapterSmartRewindStillRewindsWhenEnabled() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    // Four seconds fits inside chapter 3 (20–30) at t=25, so the rewind is the configured
    // amount rather than the clamp at the chapter start.
    UserDefaults.standard.set(4.0, forKey: Constants.UserDefaults.smartRewindMaxInterval)
    let item = try await loadWellFormedBook(at: 25)
    item.lastPlayDate = Date().addingTimeInterval(-12 * 60 * 60)

    await sut.handleSmartRewind(item)

    XCTAssertEqual(CMTimeGetSeconds(sut.getAVPlayer().currentTime()), 21, accuracy: 0.05)
    XCTAssertEqual(item.currentChapter.index, 3)
  }

  @MainActor
  func testSmartRewindPreservesPauseTimestampAfterRestorationSample() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    UserDefaults.standard.set(4.0, forKey: Constants.UserDefaults.smartRewindMaxInterval)
    let item = try await loadWellFormedBook(at: 25)
    item.lastPlayDate = Date().addingTimeInterval(-12 * 60 * 60)
    let lastPlayTime = item.lastPlayDate

    // An accepted restoration sample persists a fresh date before rewind begins.
    sut.updateTime()
    XCTAssertGreaterThan(try XCTUnwrap(item.lastPlayDate), try XCTUnwrap(lastPlayTime))
    await sut.handleSmartRewind(item, lastPlayTime: lastPlayTime)

    XCTAssertEqual(CMTimeGetSeconds(sut.getAVPlayer().currentTime()), 21, accuracy: 0.05)
    XCTAssertEqual(item.currentChapter.index, 3)
  }

  @MainActor
  func testSmartRewindPreservesMissingPauseTimestampAfterRestorationSample() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    let item = try await loadWellFormedBook(at: 25)
    item.lastPlayDate = nil
    let lastPlayTime = item.lastPlayDate

    sut.updateTime()
    XCTAssertNotNil(item.lastPlayDate)
    await sut.handleSmartRewind(item, lastPlayTime: lastPlayTime)

    XCTAssertEqual(CMTimeGetSeconds(sut.getAVPlayer().currentTime()), 25, accuracy: 0.05)
  }

  @MainActor
  func testSmartRewindDisabledLeavesThePlayhead() async throws {
    UserDefaults.standard.set(false, forKey: Constants.UserDefaults.smartRewindEnabled)
    let item = try await loadWellFormedBook(at: 25)
    item.lastPlayDate = Date().addingTimeInterval(-12 * 60 * 60)

    await sut.handleSmartRewind(item)

    XCTAssertEqual(CMTimeGetSeconds(sut.getAVPlayer().currentTime()), 25, accuracy: 0.05)
  }

  @MainActor
  func testBoundBookRewindUsesChapterOffset() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    UserDefaults.standard.set(30.0, forKey: Constants.UserDefaults.smartRewindMaxInterval)

    // Chapter inside the file (offset 10) and, below, the first chapter of a file (offset 0)
    // whose global start is not the file start.
    let withinFile = try await loadWellFormedBook(at: 10.2, bound: true)
    withinFile.lastPlayDate = Date().addingTimeInterval(-12 * 60 * 60)
    await sut.handleSmartRewind(withinFile)
    let withinTime = CMTimeGetSeconds(sut.getAVPlayer().currentTime())
    XCTAssertGreaterThanOrEqual(withinTime, 10)
    XCTAssertLessThan(withinTime, 10.2)
    XCTAssertEqual(withinFile.currentChapter.index, 2)

    let newFile = try XCTUnwrap(sut.currentItem)
    let opening = PlayableChapter(
      title: "First of file",
      author: "Fixture",
      start: 5_000,
      duration: 40,
      relativePath: newFile.relativePath,
      remoteURL: nil,
      externalURL: nil,
      index: 1,
      chapterOffset: 0
    )
    let rebound = PlayableItem(
      title: newFile.title,
      author: newFile.author,
      chapters: [opening],
      currentTime: 5_000.3,
      duration: 5_040,
      relativePath: newFile.relativePath,
      uuid: newFile.uuid,
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: Date().addingTimeInterval(-12 * 60 * 60),
      isFinished: false,
      isBoundBook: true
    )
    sut.currentItem = rebound
    sut.jumpTo(5_000.3, recordBookmark: false)
    await awaitPlayerTime(0.3)
    rebound.lastPlayDate = Date().addingTimeInterval(-12 * 60 * 60)

    await sut.handleSmartRewind(rebound)

    let openedAt = CMTimeGetSeconds(sut.getAVPlayer().currentTime())
    XCTAssertGreaterThanOrEqual(openedAt, 0)
    XCTAssertLessThan(openedAt, 0.3)
    XCTAssertEqual(rebound.currentChapter.index, 1)
    XCTAssertEqual(playbackServiceMock.getPlayableItemAfterParentFolderAutoplayedRestartFinishedCallsCount, 0)
  }

  @MainActor
  func testResumeAfterEndOfChapterTimerContinuesTheNextChapter() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    UserDefaults.standard.set(30.0, forKey: Constants.UserDefaults.smartRewindMaxInterval)
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.autoTimerEnabled)
    installPlaybackRecord()
    _ = try await loadWellFormedBook(at: 9)
    SleepTimer.shared.setTimer(.endOfChapter)

    sut.play()
    try await waitUntil("paused at chapter 2") {
      guard let item = self.sut.currentItem else { return false }
      return !self.sut.isPlaying && item.currentChapter.index == 2 && item.currentTime >= 10
    }
    XCTAssertEqual(SleepTimer.shared.state, .off)

    let immediateMark = sut.currentItem?.currentTime ?? 0
    sut.play()
    try await waitUntil("immediate resume plays chapter 2 with the timer armed") {
      self.resumedIntoChapterTwo(past: immediateMark)
    }

    sut.pause()
    let overnightMark = sut.currentItem?.currentTime ?? 0
    sut.currentItem?.lastPlayDate = Date().addingTimeInterval(-12 * 60 * 60)
    // Lock-screen play goes through `playPause()` on this manager.
    sut.playPause()
    try await waitUntil("overnight resume plays chapter 2 with the timer armed") {
      self.resumedIntoChapterTwo(past: overnightMark)
    }
  }

  @MainActor
  func testTransientBoundarySampleDoesNotEndTheChapterTimer() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.autoTimerEnabled)
    let item = try await loadWellFormedBook(at: 10.2)
    SleepTimer.shared.setTimer(.endOfChapter)

    await awaitPlayerTime(9.99)
    sut.updateTime()

    XCTAssertEqual(item.currentChapter.index, 2)
    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter)
    XCTAssertFalse(sut.isPlaying)

    await awaitPlayerTime(8)
    sut.updateTime()

    XCTAssertEqual(item.currentChapter.index, 1)
    XCTAssertEqual(SleepTimer.shared.state, .off)
  }

  @MainActor
  func testCountdownAndDisabledAutoTimerKeepTheirBehavior() async throws {
    installPlaybackRecord()
    let item = try await loadWellFormedBook(at: 15)
    item.lastPlayDate = nil

    UserDefaults.standard.set(false, forKey: Constants.UserDefaults.autoTimerEnabled)
    SleepTimer.shared.setTimer(.off)
    sut.play()
    try await waitUntil("plays with the automatic timer disabled") { self.sut.isPlaying }
    XCTAssertEqual(SleepTimer.shared.state, .off)
    sut.pause()

    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.autoTimerEnabled)
    SleepTimer.shared.setTimer(.countdown(300))
    item.lastPlayDate = nil
    sut.play()
    try await waitUntil("plays with a countdown timer") { self.sut.isPlaying }
    guard case .countdown = SleepTimer.shared.state else {
      return XCTFail("countdown timer was \(SleepTimer.shared.state)")
    }
  }

  @MainActor
  func testShakeToResumeRearmsTheTimerWithoutStopping() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    UserDefaults.standard.set(30.0, forKey: Constants.UserDefaults.smartRewindMaxInterval)
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.autoTimerEnabled)
    installPlaybackRecord()
    let item = try await loadWellFormedBook(at: 10.2)
    SleepTimer.shared.setTimer(.endOfChapter)
    NotificationCenter.default.post(name: .chapterChange, object: nil)
    XCTAssertEqual(SleepTimer.shared.state, .off)

    item.lastPlayDate = Date().addingTimeInterval(-12 * 60 * 60)
    // Shake rearms the remembered timer and only then calls `play()`.
    SleepTimer.shared.restartTimer()
    sut.play()

    let mark = item.currentTime
    try await waitUntil("shake resume keeps chapter 2 and the timer") {
      self.resumedIntoChapterTwo(past: mark)
    }
  }

  @MainActor
  func testCompletedBookDoesNotReplayOrSkipOnResume() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    UserDefaults.standard.set(30.0, forKey: Constants.UserDefaults.smartRewindMaxInterval)
    installPlaybackRecord()
    let item = try await loadWellFormedBook(at: 20)
    await awaitPlayerTime(item.duration)
    item.currentTime = item.duration
    item.currentChapter = item.chapters[3]
    item.lastPlayDate = Date().addingTimeInterval(-12 * 60 * 60)
    XCTAssertEqual(Int(item.duration), Int(CMTimeGetSeconds(sut.getAVPlayer().currentTime())))

    let played = expectation(forNotification: .bookPlayed, object: nil)
    played.isInverted = true
    sut.play()
    await fulfillment(of: [played], timeout: 1.5)

    // The finished-book return happens after `prepareForPlayback` has queued playback, so
    // `isPlaying` stays true. Audio must not start, and the book must not advance.
    XCTAssertEqual(sut.getAVPlayer().rate, 0)
    XCTAssertEqual(item.currentChapter.index, 4)
    XCTAssertEqual(item.currentTime, item.duration, accuracy: 0.05)
    XCTAssertEqual(playbackServiceMock.getPlayableItemAfterParentFolderAutoplayedRestartFinishedCallsCount, 0)
  }

  /// Chapters at 0, 10, 20 and 30 seconds, matching `m4b_WELLFORMED`.
  private func chapteredBook(
    bound: Bool = false,
    chapterOffset: TimeInterval = 0,
    globalStart: TimeInterval = 10
  ) -> PlayableItem {
    let chapter1 = PlayableChapter(
      title: "chapter 1",
      author: "author",
      start: 0,
      duration: 10,
      relativePath: "book.m4b",
      remoteURL: nil,
      externalURL: nil,
      index: 1
    )
    let chapter2 = PlayableChapter(
      title: "chapter 2",
      author: "author",
      start: globalStart,
      duration: 10,
      relativePath: "book.m4b",
      remoteURL: nil,
      externalURL: nil,
      index: 2,
      chapterOffset: chapterOffset
    )
    return PlayableItem(
      title: "book",
      author: "author",
      chapters: [chapter1, chapter2],
      currentTime: globalStart,
      duration: globalStart + 10,
      relativePath: "book.m4b",
      uuid: "LEGACY_UUID",
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: bound
    )
  }

  /// Four 10-second chapters, the same cuts as `m4b_WELLFORMED`.
  private func fixtureChapters(relativePath: String, bound: Bool) -> [PlayableChapter] {
    var chapters: [PlayableChapter] = []
    for offset in 0..<4 {
      let start = TimeInterval(offset * 10)
      chapters.append(
        PlayableChapter(
          title: "Chapter \(offset + 1)",
          author: "Fixture",
          start: start,
          duration: 10,
          relativePath: relativePath,
          remoteURL: nil,
          externalURL: nil,
          index: Int16(offset + 1),
          chapterOffset: bound ? start : 0
        )
      )
    }
    return chapters
  }

  @MainActor
  private func loadWellFormedBook(at time: TimeInterval, bound: Bool = false) async throws -> PlayableItem {
    let relativePath = "player-manager-chapter-timer.m4b"
    let source = try XCTUnwrap(
      Bundle(for: Self.self).url(forResource: "m4b_WELLFORMED", withExtension: "m4b")
    )
    let destination = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)
    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.copyItem(at: source, to: destination)
    copiedFixtureURL = destination

    let chapters = fixtureChapters(relativePath: relativePath, bound: bound)
    let item = PlayableItem(
      title: "Well Formed",
      author: "Fixture",
      chapters: chapters,
      currentTime: time,
      duration: 40,
      relativePath: relativePath,
      uuid: "chapter-timer-fixture",
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: bound
    )

    let ready = expectation(forNotification: .bookReady, object: nil)
    sut.load(item, autoplay: false)
    await fulfillment(of: [ready], timeout: 10)

    let playable = expectation(description: "player item ready")
    let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
      if self?.sut.getAVPlayer().currentItem?.status == .readyToPlay {
        timer.invalidate()
        playable.fulfill()
      }
    }
    defer { timer.invalidate() }
    await fulfillment(of: [playable], timeout: 10)

    sut.jumpTo(time, recordBookmark: false)
    let loaded = sut.currentItem ?? item
    let fileTime =
      loaded.isBoundBook
      ? loaded.getChapterTime(in: loaded.currentChapter, for: time)
      : time
    await awaitPlayerTime(fileTime)
    return loaded
  }

  @MainActor
  private func awaitPlayerTime(_ seconds: TimeInterval) async {
    await withCheckedContinuation { continuation in
      sut.getAVPlayer().seek(
        to: CMTime(seconds: seconds, preferredTimescale: 600),
        toleranceBefore: .zero,
        toleranceAfter: .zero
      ) { _ in
        continuation.resume()
      }
    }
  }

  @MainActor
  private func waitUntil(
    _ description: String,
    timeout: TimeInterval = 8,
    _ predicate: @escaping () -> Bool
  ) async throws {
    let exp = expectation(description: description)
    let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
      if predicate() {
        timer.invalidate()
        exp.fulfill()
      }
    }
    defer { timer.invalidate() }
    await fulfillment(of: [exp], timeout: timeout)
  }

  private func resumedIntoChapterTwo(past mark: TimeInterval) -> Bool {
    guard let item = sut.currentItem else { return false }

    guard case .endOfChapter = SleepTimer.shared.state else { return false }

    return sut.isPlaying && item.currentChapter.index == 2 && item.currentTime > mark + 0.4
  }

  private func installPlaybackRecord() {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    playbackRecordStack = dataManager
    libraryServiceMock.getCurrentPlaybackRecordReturnValue = PlaybackRecord.create(
      in: dataManager.getContext()
    )
  }
}
