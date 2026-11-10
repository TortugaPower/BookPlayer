//
//  PlayerManagerCharacterizationTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 11/8/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import Combine
import CoreData
import Foundation
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// Pins how `PlayerManager` loads and plays today, so the state-machine rework refactors against a
/// green baseline. The player and its items are `ControlledPlayer` and `ControlledPlayerItem`:
/// nothing loads media, and each test moves an item's status by hand.
///
/// A known bug isn't encoded as expected behaviour: its test asserts the right behaviour inside
/// `XCTExpectFailure`, so the fix fails that expectation and asks for it to be removed. Every test
/// also ends with each item's `status` observer added and removed in pairs (see `tearDown`).
final class PlayerManagerCharacterizationTests: XCTestCase {
  private var libraryService: LibraryServiceProtocolMock!
  private var playbackService: PlaybackServiceProtocolMock!
  private var coreDataStack: CoreDataStack!
  private var players: [ControlledPlayer] = []
  private var items: [ControlledPlayerItem] = []
  private var failures: [PlaybackFailure] = []
  private var savedDefaults: [String: Any] = [:]
  private var sut: PlayerManager!

  /// The player `PlayerManager` holds now: a media-services reset makes a new one
  private var player: ControlledPlayer { players[players.count - 1] }

  /// Settings on the play path that tests turn on, restored after each test
  private let touchedDefaults = [
    Constants.UserDefaults.smartRewindEnabled,
    Constants.UserDefaults.autoTimerEnabled,
    Constants.UserDefaults.lastEnabledTimer,
    Constants.UserDefaults.autoplayEnabled,
    /// Armed when a book finishes
    Constants.UserDefaults.pendingReviewPrompt,
  ]

  override func setUpWithError() throws {
    try super.setUpWithError()
    for key in touchedDefaults {
      if let value = UserDefaults.standard.object(forKey: key) {
        savedDefaults[key] = value
      }
      UserDefaults.standard.removeObject(forKey: key)
    }

    coreDataStack = CoreDataStack(testPath: "/dev/null")
    let context = coreDataStack.managedContext
    /// By entity name: each test loads the model again, so a lookup by class finds several matches
    let recordEntity = try XCTUnwrap(NSEntityDescription.entity(forEntityName: "PlaybackRecord", in: context))
    libraryService = LibraryServiceProtocolMock()
    libraryService.getCurrentPlaybackRecordReturnValue = PlaybackRecord(entity: recordEntity, insertInto: context)
    playbackService = PlaybackServiceProtocolMock()
    /// Mirrors production, which moves the playhead and stamps the play date Smart Rewind reads
    playbackService.updatePlaybackTimeItemTimeClosure = { item, time in
      item.currentTime = time
      item.lastPlayDate = Date()
    }
    playbackService.getNextChapterFromAfterClosure = { item, chapter in
      item.chapters.first { $0.index == chapter.index + 1 }
    }
    let syncService = SyncServiceProtocolMock()
    syncService.isActive = false
    let speedService = SpeedServiceProtocolMock()
    speedService.getSpeedRelativePathReturnValue = 1

    sut = PlayerManager(
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService,
      speedService: speedService,
      shakeMotionService: ShakeMotionServiceProtocolMock(),
      widgetReloadService: WidgetReloadService(),
      hasStreamingEnabled: { true },
      presentFailure: { [unowned self] in self.failures.append($0) },
      engine: AVPlayerEngine(makePlayer: { [unowned self] in
        let player = ControlledPlayer()
        self.players.append(player)
        return player
      }),
      makePlayerItem: { [unowned self] asset in
        let item = ControlledPlayerItem(asset: asset)
        self.items.append(item)
        return item
      },
      /// The suite pins ordering, not threading. In the app `loadChapterOperation` runs on a
      /// background queue and registers the `status` observer there; how that races with `pause()`
      /// and `play()` on main is out of reach here. Rework PR 5 moves the work onto the main actor.
      loadQueue: .main
    )
  }

  override func tearDown() {
    sut.stop()

    /// Scenario 13: whatever the test did, the `status` observer was added and removed in pairs
    for (index, item) in items.enumerated() {
      XCTAssertEqual(
        item.statusObserverAdds,
        item.statusObserverRemoves,
        "item \(index) was left with its status observer registered"
      )
      XCTAssertEqual(
        item.unbalancedRemoves,
        0,
        "item \(index) had an observer removed that was never added, which crashes in production"
      )
    }
    for (index, player) in players.enumerated() {
      XCTAssertEqual(
        player.unknownTimeObserverRemovals,
        0,
        "player \(index) was asked to remove a time observer it never added, which raises in production"
      )
    }

    SleepTimer.shared.setTimer(.off)
    for key in touchedDefaults {
      if let value = savedDefaults[key] {
        UserDefaults.standard.set(value, forKey: key)
      } else {
        UserDefaults.standard.removeObject(forKey: key)
      }
    }

    sut = nil
    players = []
    items = []
    failures = []
    savedDefaults = [:]
    super.tearDown()
  }

  // MARK: - 1–5: loading and queued playback

  /// Scenario 1
  @MainActor
  func testALoadWithAutoplayPlaysOnceTheItemIsReady() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .wantsToPlay(.user))

    XCTAssertTrue(item.isStatusObserved)
    XCTAssertTrue(player.playCalls.isEmpty, "nothing plays before the item is ready")

    item.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }
    await settle()

    XCTAssertEqual(player.playCalls, [1])
    XCTAssertFalse(item.isStatusObserved, "the observer goes once the item is ready")
  }

  /// Scenario 2: the last book, loaded silently at launch
  @MainActor
  func testALaunchPreloadRestoresThePositionWithoutPlaying() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(currentTime: 30), intent: .idle)

    XCTAssertEqual(player.seekTargets, [30])

    item.become(.readyToPlay)
    await settle()

    XCTAssertTrue(player.playCalls.isEmpty)
  }

  /// Scenario 3: play pressed while the item is still loading
  @MainActor
  func testPlayPressedDuringALoadStartsOnceTheItemIsReady() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)

    sut.play()
    await settle()
    XCTAssertTrue(player.playCalls.isEmpty, "it waits for the item")

    item.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }
    await settle()

    XCTAssertEqual(player.playCalls.count, 1)
  }

  /// Scenario 4
  @MainActor
  func testPausingDuringALoadKeepsItSilentOnceReady() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .wantsToPlay(.user))

    sut.pause()
    item.become(.readyToPlay)
    await settle()

    XCTAssertTrue(player.playCalls.isEmpty)
    XCTAssertFalse(item.isStatusObserved)
  }

  /// Scenario 5
  @MainActor
  func testASecondLoadSupersedesTheFirst() async throws {
    let first = try await loadUntilInPlayer(singleFileBook("first.m4b"), intent: .wantsToPlay(.user))
    let second = try await loadUntilInPlayer(singleFileBook("second.m4b"), intent: .wantsToPlay(.user))

    XCTAssertFalse(first.isStatusObserved)
    first.become(.readyToPlay)
    await settle()
    XCTAssertTrue(player.playCalls.isEmpty, "the superseded item can't start playback")

    second.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }
    await settle()

    XCTAssertEqual(player.playCalls.count, 1)
    XCTAssertTrue(player.currentItem === second)
  }

  // MARK: - 6–7: failed items

  /// Scenario 6
  @MainActor
  func testAnUnavailableFileIsReloadedOnceThenReported() async throws {
    let unavailable = NSError(domain: NSURLErrorDomain, code: NSURLErrorResourceUnavailable)
    let first = try await loadUntilInPlayer(singleFileBook(), intent: .wantsToPlay(.user))

    first.become(.failed, error: unavailable)
    let second = try await nextItemInPlayer(after: 1)
    await settle()
    XCTAssertTrue(failures.isEmpty, "the first failure reloads silently")

    second.become(.failed, error: unavailable)
    await waitUntil("the failure is reported") { !self.failures.isEmpty }
    await settle()

    XCTAssertEqual(failures.count, 1)
    XCTAssertEqual(items.count, 2, "only one reload")
    XCTAssertTrue(player.playCalls.isEmpty)
  }

  /// Scenario 7: a media-server stream
  @MainActor
  func testAFailedStreamIsRetriedOnceThenReported() async throws {
    let timedOut = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
    let first = try await loadUntilInPlayer(streamedBook(), intent: .wantsToPlay(.user))

    first.become(.failed, error: timedOut)
    let second = try await nextItemInPlayer(after: 1)
    await settle()
    XCTAssertTrue(failures.isEmpty, "the first failure retries silently")

    second.become(.failed, error: timedOut)
    await waitUntil("the failure is reported") { !self.failures.isEmpty }
    await settle()

    XCTAssertEqual(failures.count, 1)
    XCTAssertEqual(items.count, 2, "only one retry")
  }

  // MARK: - 8–9: system events

  /// Scenario 8
  @MainActor
  func testAnInterruptionPausesThenResumesAsAnAutomaticPlay() async throws {
    try await loadAndPlay(singleFileBook())

    postInterruption(.began)
    XCTAssertEqual(player.pauseCalls, 1)

    postInterruption(.ended, options: .shouldResume)
    await waitUntil("playback resumes") { self.player.playCalls.count == 2 }
  }

  /// Scenario 9: the reset makes a new player, and the next play loads the book into it where it was
  @MainActor
  func testPlayAfterAMediaServicesResetReachesAPlayerWithTheItem() async throws {
    try await loadAndPlay(singleFileBook(currentTime: 30))
    let original = player
    var playing: [Bool] = []
    let subscription = sut.isPlayingPublisher().sink { playing.append($0) }
    defer { subscription.cancel() }

    NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)

    XCTAssertEqual(players.count, 2, "the reset makes a new player")
    XCTAssertFalse(original.hasTickObserver, "the tick leaves the old player")
    XCTAssertTrue(player.hasTickObserver, "and reaches the new one")
    XCTAssertEqual(original.boundaryTimes, [], "so does the chapter end")
    XCTAssertEqual(player.boundaryTimes, [50])

    sut.play()
    let reloaded = try await nextItemInPlayer(after: 1)
    XCTAssertTrue(player.playCalls.isEmpty, "nothing plays before the reloaded item is ready")

    reloaded.become(.readyToPlay)
    await waitUntil("playback starts on the new player") { !self.player.playCalls.isEmpty }

    XCTAssertTrue(player.currentItem === reloaded, "the new player has the item when playback starts")
    XCTAssertEqual(player.seekTargets, [30], "at the position it was at")
    await settle()
    XCTAssertEqual(playing.last, true, "a subscriber made before the reset follows the new player")
  }

  /// Scenario 9, a reset while the last book still loads silently: its observer goes with the old item
  @MainActor
  func testAResetDuringASilentLoadReloadsTheBookOnPlay() async throws {
    let first = try await loadUntilInPlayer(singleFileBook(currentTime: 30), intent: .idle)
    XCTAssertTrue(first.isStatusObserved)

    NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)

    XCTAssertFalse(first.isStatusObserved, "the reset removes the observer from the old item")

    sut.play()
    let reloaded = try await nextItemInPlayer(after: 1)
    reloaded.become(.readyToPlay)
    await waitUntil("playback starts on the new player") { !self.player.playCalls.isEmpty }

    XCTAssertTrue(player.currentItem === reloaded)
    XCTAssertEqual(player.seekTargets, [30])
  }

  // MARK: - 10: the end of a file

  /// Scenario 10, a volume's middle file
  @MainActor
  func testAVolumeMovesToTheNextFileWhenOneEnds() async throws {
    let first = try await loadAndPlay(boundBook())

    NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: first)
    let second = try await nextItemInPlayer(after: 1)

    XCTAssertEqual(sut.currentItem?.currentChapter.index, 2)

    second.become(.readyToPlay)
    await waitUntil("the next file plays") { self.player.playCalls.count == 2 }
  }

  /// Scenario 10, the last file
  @MainActor
  func testTheLastFileEndingFinishesTheBook() async throws {
    let item = try await loadAndPlay(boundBook(currentTime: 60))
    let bookEnd = expectation(forNotification: .bookEnd, object: nil)
    bookEnd.assertForOverFulfill = false

    NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: item)
    await fulfillment(of: [bookEnd], timeout: 1)

    XCTAssertEqual(libraryService.markAsFinishedFlagRelativePathCallsCount, 1)
    XCTAssertEqual(sut.currentItem?.isFinished, true)
    XCTAssertEqual(items.count, 1, "nothing else loads with autoplay off")
  }

  // MARK: - 11–12: the sleep timer

  /// Scenario 11: the end-of-chapter timer pauses as playback crosses the chapter's end, parked at the
  /// next chapter's start, so the resume begins at its first word and can't cross back (GH #1486)
  @MainActor
  func testTheEndOfChapterTimerPausesOnTheBoundaryAndResumeStartsTheNextChapter() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.autoTimerEnabled)
    try await loadAndPlay(singleFileBook())
    SleepTimer.shared.setTimer(.endOfChapter)

    player.crossBoundary(at: 50)

    XCTAssertEqual(player.pauseCalls, 1, "the timer pauses as playback crosses the chapter's end")
    XCTAssertEqual(sut.currentItem?.currentChapter.index, 2)
    XCTAssertEqual(SleepTimer.shared.state, .off)
    XCTAssertEqual(player.preciseSeekTargets.count, 1, "parked with a precise seek")
    XCTAssertEqual(player.preciseSeekTargets.first ?? -1, 50.01, accuracy: 0.0001, "10 ms into the next chapter")
    XCTAssertEqual(sut.currentItem?.currentTime ?? -1, 50.01, accuracy: 0.0001)

    /// Resumed a minute later: Smart Rewind has next to nothing to rewind at the chapter's start
    sut.currentItem?.lastPlayDate = Date().addingTimeInterval(-60)
    let seeksBeforeResume = player.seekTargets.count
    sut.play()
    await waitUntil("playback resumes") { self.player.playCalls.count == 2 }
    await settle()

    XCTAssertEqual(player.seekTargets.count, seeksBeforeResume, "the resume doesn't seek")
    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter, "the remembered timer is armed again")

    /// Half a second into chapter 2, the tick finds it still there: no second pause
    player.reportedTime = 50.5
    player.fireTick()

    XCTAssertEqual(player.pauseCalls, 1, "resuming doesn't pause again")
    XCTAssertEqual(sut.currentItem?.currentChapter.index, 2)
  }

  /// Scenario 11, the tick noticing a chapter's end before the crossing: it still ends the timer, a
  /// moment late, and the crossing then leaves it alone
  @MainActor
  func testATickPastTheChapterEndStillEndsTheTimer() async throws {
    try await loadAndPlay(singleFileBook())
    SleepTimer.shared.setTimer(.endOfChapter)

    player.reportedTime = 50.3
    player.fireTick()

    XCTAssertEqual(player.pauseCalls, 1, "the timer pauses on the tick")
    XCTAssertEqual(sut.currentItem?.currentChapter.index, 2)
    XCTAssertEqual(SleepTimer.shared.state, .off)

    player.crossBoundary(at: 50)

    XCTAssertEqual(player.pauseCalls, 1)
    XCTAssertTrue(player.preciseSeekTargets.isEmpty)
  }

  /// Scenario 11 without the timer: a crossing changes nothing, and the tick moves the chapter as before
  @MainActor
  func testWithoutTheEndOfChapterTimerACrossingChangesNothing() async throws {
    try await loadAndPlay(singleFileBook())

    player.crossBoundary(at: 50)

    XCTAssertEqual(player.pauseCalls, 0)
    XCTAssertTrue(player.preciseSeekTargets.isEmpty)
    XCTAssertEqual(sut.currentItem?.currentChapter.index, 1)

    player.fireTick()

    XCTAssertEqual(sut.currentItem?.currentChapter.index, 2)
  }

  /// The chapter ends observed are those inside the file in the player, but its last
  @MainActor
  func testTheChapterEndsOfTheFileInThePlayerAreObserved() async throws {
    _ = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    XCTAssertEqual(player.boundaryTimes, [50])

    /// A volume of one-chapter files: each ends with its file
    _ = try await loadUntilInPlayer(boundBook(), intent: .idle)
    XCTAssertEqual(player.boundaryTimes, [])
  }

  /// Scenario 11 inside a volume's file that holds two chapters: its times count from the file's start
  @MainActor
  func testTheEndOfChapterTimerParksInsideAVolumesFile() async throws {
    try await loadAndPlay(nestedVolume(currentTime: 60))
    XCTAssertEqual(player.boundaryTimes, [30], "chapter 2 ends 30 s into the second file, at 80 s in the book")
    SleepTimer.shared.setTimer(.endOfChapter)

    player.crossBoundary(at: 30)

    XCTAssertEqual(player.pauseCalls, 1)
    XCTAssertEqual(sut.currentItem?.currentChapter.index, 3)
    XCTAssertEqual(player.preciseSeekTargets.first ?? -1, 30.01, accuracy: 0.0001, "chapter 3 starts 30 s into that file")
    XCTAssertEqual(sut.currentItem?.currentTime ?? -1, 80.01, accuracy: 0.0001)
  }

  /// Scenario 11 on chapter times that don't add up exactly: the ended chapter's `start + duration` rounds
  /// past the next one's start, and a book reopened from the saved time must still be in the next chapter
  @MainActor
  func testAParkedPositionReopensInTheNextChapter() async throws {
    XCTAssertGreaterThan(600.003 + 1234.567, 1834.57, "the rounding this guards against")
    let tied = book(
      "tied.m4b",
      chapters: [
        chapter(1, start: 0, duration: 600.003, relativePath: "tied.m4b"),
        chapter(2, start: 600.003, duration: 1234.567, relativePath: "tied.m4b"),
        chapter(3, start: 1834.57, duration: 100, relativePath: "tied.m4b"),
      ],
      currentTime: 700
    )
    try await loadAndPlay(tied)
    SleepTimer.shared.setTimer(.endOfChapter)

    player.crossBoundary(at: 600.003 + 1234.567)

    let saved = try XCTUnwrap(sut.currentItem?.currentTime)
    XCTAssertEqual(book("tied.m4b", chapters: tied.chapters, currentTime: saved).currentChapter.index, 3)
  }

  /// Scenario 11, Smart Rewind back to a chapter's start: AVPlayer reports the chapter before it ending as
  /// playback starts there, which mustn't end the re-armed timer
  @MainActor
  func testResumingFromAChaptersStartDoesNotEndTheTimer() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    rememberEndOfChapterTimer()
    let item = try await loadUntilInPlayer(singleFileBook(currentTime: 55), intent: .idle)
    item.become(.readyToPlay)
    await settle()
    /// Paused 5 s into chapter 2 a day ago: Smart Rewind goes back to its start
    sut.currentItem?.lastPlayDate = Date().addingTimeInterval(-86_400)

    sut.play()
    await waitUntil("playback resumes") { !self.player.playCalls.isEmpty }
    await settle()

    XCTAssertEqual(player.seekTargets.last ?? -1, 50, accuracy: 0.0001, "rewound to chapter 2's start")
    XCTAssertEqual(player.pauseCalls, 0, "starting on chapter 1's end doesn't pause")
    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter)
  }

  /// Chapters re-parsed while the book is loaded: their ends replace the old ones
  @MainActor
  func testReloadedChaptersAreObservedAtTheirEnds() async throws {
    _ = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    XCTAssertEqual(player.boundaryTimes, [50])
    libraryService.getSimpleItemWithReturnValue = SimpleLibraryItem(
      title: "book.m4b",
      details: "author",
      speed: 1,
      currentTime: 0,
      duration: 100,
      percentCompleted: 0,
      isFinished: false,
      relativePath: "book.m4b",
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: "book.m4b",
      lastPlayDate: nil,
      type: .book,
      uuid: "LEGACY_UUID"
    )
    playbackService.getPlayableItemFromReturnValue = book(
      "book.m4b",
      chapters: [
        chapter(1, start: 0, duration: 40, relativePath: "book.m4b"),
        chapter(2, start: 40, duration: 60, relativePath: "book.m4b"),
      ]
    )

    sut.reloadCurrentItem()

    XCTAssertEqual(player.boundaryTimes, [40])
  }

  /// Scenario 12, a play the user starts
  @MainActor
  func testAManualPlayArmsTheRememberedTimer() async throws {
    rememberEndOfChapterTimer()
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    item.become(.readyToPlay)

    sut.play()
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }

    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter)
  }

  /// Scenario 12, a tap on a new book in the library: the play starts once its item loads
  @MainActor
  func testANewBookTapArmsTheRememberedTimer() async throws {
    rememberEndOfChapterTimer()

    try await loadAndPlay(singleFileBook())

    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter)
  }

  /// Scenario 12, play pressed while the item is still loading: still the user's play once it starts
  @MainActor
  func testPlayPressedDuringALoadArmsTheRememberedTimer() async throws {
    rememberEndOfChapterTimer()
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)

    sut.play()
    await settle()
    item.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }

    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter)
  }

  /// Scenario 12, a tap whose file had to be reloaded: the retry keeps the user's play
  @MainActor
  func testAReloadedTapStillArmsTheRememberedTimer() async throws {
    rememberEndOfChapterTimer()
    let first = try await loadUntilInPlayer(singleFileBook(), intent: .wantsToPlay(.user))

    first.become(.failed, error: NSError(domain: NSURLErrorDomain, code: NSURLErrorResourceUnavailable))
    let second = try await nextItemInPlayer(after: 1)
    second.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }

    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter)
  }

  /// Scenario 12, the next book starting after one finishes
  @MainActor
  func testTheNextBookAfterAFinishedOneDoesNotArmTheRememberedTimer() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.autoplayEnabled)
    playbackService.getPlayableItemAfterParentFolderAutoplayedRestartFinishedReturnValue = singleFileBook("next.m4b")
    rememberEndOfChapterTimer()
    let first = try await loadAndPlay(boundBook(currentTime: 60), origin: .system)

    NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: first)
    let next = try await nextItemInPlayer(after: 1)
    next.become(.readyToPlay)
    await waitUntil("the next book plays") { self.player.playCalls.count == 2 }

    XCTAssertEqual(sut.currentItem?.relativePath, "next.m4b")
    XCTAssertEqual(SleepTimer.shared.state, .off)
  }

  /// Scenario 12, playback resuming after a call
  @MainActor
  func testAnInterruptionsResumeDoesNotArmTheRememberedTimer() async throws {
    rememberEndOfChapterTimer()
    try await loadAndPlay(singleFileBook(), origin: .system)

    postInterruption(.began)
    postInterruption(.ended, options: .shouldResume)
    await waitUntil("playback resumes") { self.player.playCalls.count == 2 }

    XCTAssertEqual(SleepTimer.shared.state, .off)
  }

  /// Scenario 12, CarPlay connecting: the muted play that claims Now Playing, then pauses
  @MainActor
  func testClaimingNowPlayingDoesNotArmTheRememberedTimer() async throws {
    rememberEndOfChapterTimer()
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    item.become(.readyToPlay)
    await settle()

    XCTAssertTrue(sut.claimNowPlayingThenPause())
    await waitUntil("the claim pauses") { self.player.pauseCalls == 1 }

    XCTAssertEqual(player.playCalls.count, 1)
    XCTAssertEqual(SleepTimer.shared.state, .off)
  }

  // MARK: - Known bugs

  /// A volume's next file chosen while the current one is still loading: the "Clean just in case" block
  /// in `loadPlayerItem(for:forceRefreshURL:)` removes the old observer by hand but leaves
  /// `observeStatus` true, so `observeStatus = true` for the new item is a no-op.
  @MainActor
  func testAChapterChangeDuringALoadObservesTheNewItem() async throws {
    let first = try await loadUntilInPlayer(boundBook(), intent: .wantsToPlay(.user))
    let nextChapter = try XCTUnwrap(sut.currentItem?.chapters.last)

    sut.jumpToChapter(nextChapter)
    let second = try await nextItemInPlayer(after: 1)

    XCTAssertFalse(first.isStatusObserved)
    XCTExpectFailure("Bug: the new item is never observed. Fixed by rework PR 5 (ItemLoad).") {
      XCTAssertTrue(second.isStatusObserved)
    }

    second.become(.readyToPlay)
    await settle()

    XCTExpectFailure("Bug: so the queued play never starts. Fixed by rework PR 5 (ItemLoad).") {
      XCTAssertEqual(player.playCalls.count, 1)
    }
  }

  // MARK: - Books

  private func chapter(
    _ index: Int16,
    start: TimeInterval,
    duration: TimeInterval,
    relativePath: String,
    externalURL: URL? = nil,
    chapterOffset: TimeInterval = 0
  ) -> PlayableChapter {
    PlayableChapter(
      title: "chapter \(index)",
      author: "author",
      start: start,
      duration: duration,
      relativePath: relativePath,
      remoteURL: nil,
      externalURL: externalURL,
      index: index,
      chapterOffset: chapterOffset
    )
  }

  private func book(
    _ relativePath: String,
    chapters: [PlayableChapter],
    currentTime: TimeInterval = 0,
    isBoundBook: Bool = false
  ) -> PlayableItem {
    PlayableItem(
      title: relativePath,
      author: "author",
      chapters: chapters,
      currentTime: currentTime,
      duration: chapters.map(\.end).max() ?? 0,
      relativePath: relativePath,
      uuid: "LEGACY_UUID",
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: isBoundBook
    )
  }

  /// One file with two chapters, 0–50 s and 50–100 s. Nothing is on disk: the player never loads it
  private func singleFileBook(_ relativePath: String = "book.m4b", currentTime: TimeInterval = 0) -> PlayableItem {
    book(
      relativePath,
      chapters: [
        chapter(1, start: 0, duration: 50, relativePath: relativePath),
        chapter(2, start: 50, duration: 50, relativePath: relativePath),
      ],
      currentTime: currentTime
    )
  }

  /// A volume: one file per chapter
  private func boundBook(currentTime: TimeInterval = 0) -> PlayableItem {
    book(
      "volume",
      chapters: [
        chapter(1, start: 0, duration: 50, relativePath: "volume/1.mp3"),
        chapter(2, start: 50, duration: 50, relativePath: "volume/2.mp3"),
      ],
      currentTime: currentTime,
      isBoundBook: true
    )
  }

  /// A volume: a one-chapter file, 0–50 s, then a file holding two chapters, 50–80 s and 80–100 s
  private func nestedVolume(currentTime: TimeInterval = 0) -> PlayableItem {
    book(
      "nested",
      chapters: [
        chapter(1, start: 0, duration: 50, relativePath: "nested/1.mp3"),
        chapter(2, start: 50, duration: 30, relativePath: "nested/2.m4b"),
        chapter(3, start: 80, duration: 20, relativePath: "nested/2.m4b", chapterOffset: 30),
      ],
      currentTime: currentTime,
      isBoundBook: true
    )
  }

  /// A Jellyfin book: it streams from its URL and has no file on disk
  private func streamedBook() -> PlayableItem {
    book(
      "streamed.m4b",
      chapters: [
        chapter(
          1,
          start: 0,
          duration: 100,
          relativePath: "streamed.m4b",
          externalURL: URL(string: "https://jelly.example.com/stream")
        )
      ]
    )
  }

  // MARK: - Driving the manager

  /// Loads `book` and returns its item once `PlayerManager` has handed it to the player
  @MainActor
  private func loadUntilInPlayer(
    _ book: PlayableItem,
    intent: PlayIntent,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async throws -> ControlledPlayerItem {
    let count = items.count
    sut.load(book, intent: intent)
    return try await nextItemInPlayer(after: count, file: file, line: line)
  }

  /// Loads `book` to play, by default as a tap in the library does, makes its item ready and waits
  /// for playback to start
  @discardableResult
  @MainActor
  private func loadAndPlay(
    _ book: PlayableItem,
    origin: PlayOrigin = .user,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async throws -> ControlledPlayerItem {
    let item = try await loadUntilInPlayer(book, intent: .wantsToPlay(origin), file: file, line: line)
    item.become(.readyToPlay)
    await waitUntil("playback starts", file: file, line: line) { !self.player.playCalls.isEmpty }
    return item
  }

  /// Waits for an item beyond the first `count` to reach the player
  @MainActor
  private func nextItemInPlayer(
    after count: Int,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async throws -> ControlledPlayerItem {
    await waitUntil("a new item in the player", file: file, line: line) {
      self.items.count > count && self.player.currentItem === self.items.last
    }
    return try XCTUnwrap(items.count > count ? items.last : nil, file: file, line: line)
  }

  /// Lets the load's hops (a `Task`, `OperationQueue.main`, `DispatchQueue.main`) run until `condition` holds
  @MainActor
  private func waitUntil(
    _ what: String,
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () -> Bool
  ) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
      guard Date() < deadline else {
        XCTFail("Timed out waiting until \(what)", file: file, line: line)
        return
      }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
  }

  /// Gives pending main-queue work time to run, before checking something did NOT happen
  @MainActor
  private func settle() async {
    try? await Task.sleep(nanoseconds: 200_000_000)
  }

  private func postInterruption(
    _ type: AVAudioSession.InterruptionType,
    options: AVAudioSession.InterruptionOptions = []
  ) {
    NotificationCenter.default.post(
      name: AVAudioSession.interruptionNotification,
      object: nil,
      userInfo: [
        AVAudioSessionInterruptionTypeKey: type.rawValue,
        AVAudioSessionInterruptionOptionKey: options.rawValue,
      ]
    )
  }

  /// The auto timer on, with the end-of-chapter timer as the one it remembers but not running
  private func rememberEndOfChapterTimer() {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.autoTimerEnabled)
    SleepTimer.shared.setTimer(.endOfChapter)
    /// Ends it the way a chapter change does, which keeps it as the remembered one
    NotificationCenter.default.post(name: .chapterChange, object: nil)
  }
}
