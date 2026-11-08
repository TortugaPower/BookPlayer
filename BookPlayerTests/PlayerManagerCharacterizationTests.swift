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
      makePlayer: { [unowned self] in
        let player = ControlledPlayer()
        self.players.append(player)
        return player
      },
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
    let item = try await loadUntilInPlayer(singleFileBook(), autoplay: true)

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
    let item = try await loadUntilInPlayer(singleFileBook(currentTime: 30), autoplay: false)

    XCTAssertEqual(player.seekTargets, [30])

    item.become(.readyToPlay)
    await settle()

    XCTAssertTrue(player.playCalls.isEmpty)
  }

  /// Scenario 3: play pressed while the item is still loading
  @MainActor
  func testPlayPressedDuringALoadStartsOnceTheItemIsReady() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(), autoplay: false)

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
    let item = try await loadUntilInPlayer(singleFileBook(), autoplay: true)

    sut.pause()
    item.become(.readyToPlay)
    await settle()

    XCTAssertTrue(player.playCalls.isEmpty)
    XCTAssertFalse(item.isStatusObserved)
  }

  /// Scenario 5
  @MainActor
  func testASecondLoadSupersedesTheFirst() async throws {
    let first = try await loadUntilInPlayer(singleFileBook("first.m4b"), autoplay: true)
    let second = try await loadUntilInPlayer(singleFileBook("second.m4b"), autoplay: true)

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
    let first = try await loadUntilInPlayer(singleFileBook(), autoplay: true)

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
    let first = try await loadUntilInPlayer(streamedBook(), autoplay: true)

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

  /// Scenario 9
  @MainActor
  func testPlayAfterAMediaServicesResetReachesAPlayerWithTheItem() async throws {
    try await loadAndPlay(singleFileBook())
    let original = player

    NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)

    XCTAssertEqual(players.count, 2, "the reset makes a new player")
    XCTAssertEqual(original.removedTimeObservers, 1, "the tick leaves the old player")

    sut.play()
    await waitUntil("play reaches the new player") { !self.player.playCalls.isEmpty }

    XCTExpectFailure(
      "Bug: the new player never gets the item, which PlayerManager still holds as ready, so play() starts an empty player. Fixed by PR 3 (PlayerHandle)."
    ) {
      XCTAssertNotNil(player.currentItem, "the new player has the item when playback starts")
    }
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

  /// Scenario 11, in a single-file book where only the 1 s tick notices the chapter end
  @MainActor
  func testTheEndOfChapterTimerPausesAfterTheBoundaryAndResumeContinues() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.autoTimerEnabled)
    try await loadAndPlay(singleFileBook())
    SleepTimer.shared.setTimer(.endOfChapter)

    /// The first tick past the boundary, 0.3 s into chapter 2
    player.reportedTime = 50.3
    player.fireTick()

    XCTAssertEqual(player.pauseCalls, 1, "the timer pauses on the tick that crosses the boundary")
    XCTAssertEqual(sut.currentItem?.currentChapter.index, 2)
    XCTAssertEqual(SleepTimer.shared.state, .off)

    /// Resumed a minute later, so Smart Rewind's cap is the time spent in the chapter
    sut.currentItem?.lastPlayDate = Date().addingTimeInterval(-60)
    sut.play()
    await waitUntil("playback resumes") { self.player.playCalls.count == 2 }
    await settle()

    XCTAssertEqual(player.seekTargets.last ?? -1, 50, accuracy: 0.0001, "Smart Rewind goes back to the chapter start")
    XCTAssertEqual(player.pauseCalls, 1, "resuming doesn't pause again")
    XCTAssertEqual(sut.currentItem?.currentChapter.index, 2)
    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter, "the remembered timer is armed again")
  }

  /// Scenario 12, a play the user starts
  @MainActor
  func testAManualPlayArmsTheRememberedTimer() async throws {
    rememberEndOfChapterTimer()
    let item = try await loadUntilInPlayer(singleFileBook(), autoplay: false)
    item.become(.readyToPlay)

    sut.play()
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }

    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter)
  }

  /// Scenario 12, a play that starts once the item loads: a tap on a book in the library today.
  /// Decided 2026-11-08 that a new-book tap should arm the timer (rework PR 2).
  @MainActor
  func testAPlayStartedByALoadDoesNotArmTheRememberedTimer() async throws {
    rememberEndOfChapterTimer()

    try await loadAndPlay(singleFileBook())

    XCTAssertEqual(SleepTimer.shared.state, .off)
  }

  // MARK: - Known bugs

  /// A volume's next file chosen while the current one is still loading: the "Clean just in case" block
  /// in `loadPlayerItem(for:forceRefreshURL:)` removes the old observer by hand but leaves
  /// `observeStatus` true, so `observeStatus = true` for the new item is a no-op.
  @MainActor
  func testAChapterChangeDuringALoadObservesTheNewItem() async throws {
    let first = try await loadUntilInPlayer(boundBook(), autoplay: true)
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
    externalURL: URL? = nil
  ) -> PlayableChapter {
    PlayableChapter(
      title: "chapter \(index)",
      author: "author",
      start: start,
      duration: duration,
      relativePath: relativePath,
      remoteURL: nil,
      externalURL: externalURL,
      index: index
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
    autoplay: Bool,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async throws -> ControlledPlayerItem {
    let count = items.count
    sut.load(book, autoplay: autoplay)
    return try await nextItemInPlayer(after: count, file: file, line: line)
  }

  /// Loads `book` with autoplay, makes its item ready and waits for playback to start
  @discardableResult
  @MainActor
  private func loadAndPlay(
    _ book: PlayableItem,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async throws -> ControlledPlayerItem {
    let item = try await loadUntilInPlayer(book, autoplay: true, file: file, line: line)
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
