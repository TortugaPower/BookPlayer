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
  var syncServiceMock: SyncServiceProtocolMock!
  /// Read live by `sut`'s entitlement closure. A test flips this rather than building a second
  /// `PlayerManager`: two of them means two AVPlayers, and the one going out of scope takes its
  /// still-registered periodic time observer with it, which aborts the process.
  var streamingEnabled = true
  var sut: PlayerManager!

  override func setUp() {
    // Clean up stored configs
    UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.chapterContextEnabled)
    UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.remainingTimeEnabled)

    self.playbackServiceMock = PlaybackServiceProtocolMock()
    /// Mirror production `PlaybackService.updatePlaybackTime(item:time:)`, which advances the
    /// playhead, so seek targets are observable in tests instead of staying frozen.
    self.playbackServiceMock.updatePlaybackTimeItemTimeClosure = { item, time in
      item.currentTime = time
    }
    self.syncServiceMock = SyncServiceProtocolMock()
    self.sut = PlayerManager(
      libraryService: LibraryServiceProtocolMock(),
      playbackService: playbackServiceMock,
      syncService: syncServiceMock,
      speedService: SpeedServiceProtocolMock(),
      shakeMotionService: ShakeMotionServiceProtocolMock(),
      widgetReloadService: WidgetReloadService(),
      // Entitled by default, so nothing here is suppressed by tier; the item half of the rule
      // is covered by MediaServersShortcutTests against PlayableChapter.
      hasStreamingEnabled: { [weak self] in self?.streamingEnabled ?? true },
      presentFailure: { _ in }
    )
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
  private func makeUnplayableExternalChapter() -> PlayableChapter {
    PlayableChapter(
      title: "test chapter",
      author: "test author",
      start: 0,
      duration: 50,
      relativePath: "no-such-file.m4b",
      remoteURL: URL(string: "https://s3.example.com/presigned"),
      externalURL: nil,
      index: 0,
      hasUnresolvedExternalHost: true
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
      hasUnresolvedExternalHost: true
    )

    let failure = sut.playbackFailure(for: chapter, title: "t", message: "m")

    XCTAssertEqual(failure.reason, .other, "the file is on disk — no server is involved")
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
      index: 0,
      hasUnresolvedExternalHost: false
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
}
