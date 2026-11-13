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
@MainActor
final class PlayerManagerCharacterizationTests: XCTestCase {
  private var libraryService: LibraryServiceProtocolMock!
  private var playbackService: PlaybackServiceProtocolMock!
  private var speedService: SpeedServiceProtocolMock!
  private var coreDataStack: CoreDataStack!
  private var players: [ControlledPlayer] = []
  private var items: [ControlledPlayerItem] = []
  private var failures: [PlaybackFailure] = []
  /// The platform of the manager made last
  private var platform: TestPlayerPlatform!
  private var savedDefaults: [String: Any] = [:]
  private var sut: PlayerManager!

  /// The player `PlayerManager` holds now: a media-services reset makes a new one
  private var player: ControlledPlayer { players[players.count - 1] }

  /// Settings on the play path that tests turn on, restored after each test
  private let touchedDefaults = [
    Constants.UserDefaults.smartRewindEnabled,
    Constants.UserDefaults.smartRewindMaxInterval,
    Constants.UserDefaults.boostVolumeEnabled,
    Constants.UserDefaults.autoTimerEnabled,
    Constants.UserDefaults.lastEnabledTimer,
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
    sut = makeManager()
  }

  /// A manager on `ControlledPlayer`s, whose items `makeItem` makes
  private func makeManager(
    makeItem: @escaping (AVURLAsset) -> ControlledPlayerItem = { ControlledPlayerItem(asset: $0) },
    streamLookup: ExternalStreamLooking = AudiobookShelfStreamLookup()
  ) -> PlayerManager {
    let syncService = SyncServiceProtocolMock()
    syncService.isActive = false
    speedService = SpeedServiceProtocolMock()
    speedService.getSpeedRelativePathReturnValue = 1
    let platform = TestPlayerPlatform()
    self.platform = platform

    return PlayerManager(
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService,
      speedService: speedService,
      platform: platform,
      widgetReloadService: WidgetReloadService(),
      hasStreamingEnabled: { true },
      presentFailure: { [unowned self] in self.failures.append($0) },
      streamLookup: streamLookup,
      engine: AVPlayerEngine(
        makePlayer: { [unowned self] in
          let player = ControlledPlayer()
          self.players.append(player)
          return player
        },
        makePlayerItem: { [unowned self] asset in
          let item = makeItem(asset)
          self.items.append(item)
          return item
        }
      )
    )
  }

  override func tearDown() {
    sut.setPlaybackCoordination(nil)
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
    platform = nil
    players = []
    items = []
    failures = []
    savedDefaults = [:]
    super.tearDown()
  }

  // MARK: - SharePlay across the shared playback engine

  func testCoordinationReattachesAfterResetAndStaysDetachedAfterTeardown() {
    let coordination = TestPlaybackCoordination()
    let original = player.playbackCoordinator
    sut.setPlaybackCoordination(coordination)
    XCTAssertEqual(coordination.attached.count, 1)
    XCTAssertTrue(original.delegate === coordination)

    NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)

    let replacement = player.playbackCoordinator
    XCTAssertEqual(players.count, 2)
    XCTAssertEqual(coordination.attached.count, 2)
    XCTAssertTrue(coordination.attached.last === replacement)
    XCTAssertTrue(coordination.detached.first === original)
    XCTAssertNil(original.delegate)
    XCTAssertTrue(replacement.delegate === coordination)

    sut.setPlaybackCoordination(nil)
    XCTAssertEqual(coordination.detached.count, 2)
    XCTAssertNil(replacement.delegate)
    NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    XCTAssertEqual(coordination.attached.count, 2, "a cleared session never reaches later players")
    XCTAssertNil(player.playbackCoordinator.delegate)
  }

  func testRemoteResumeCancelsDelayedPauseWithoutRearmingTheRememberedTimer() async throws {
    try await loadAndPlay(singleFileBook(currentTime: 30))
    rememberEndOfChapterTimer()
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.boostVolumeEnabled)
    let coordination = TestPlaybackCoordination()
    sut.setPlaybackCoordination(coordination)
    await settle()
    let activationCount = coordination.activations
    let deactivationCount = platform.deactivations
    let playCount = player.playCalls.count
    let seekCount = player.seekTargets.count

    sut.pause()
    let played = posts(of: .bookPlayed)
    let recordReads = libraryService.getCurrentPlaybackRecordCallsCount
    player.playImmediately(atRate: 1.5)
    await settle()

    XCTAssertEqual(played.books.count, 1, "the watch, Now Playing suggestions and a pending failure follow a play")
    XCTAssertTrue(played.books.first === sut.currentItem)
    XCTAssertGreaterThan(libraryService.getCurrentPlaybackRecordCallsCount, recordReads, "listening time counts again")
    XCTAssertEqual(coordination.activations, activationCount + 1)
    XCTAssertEqual(platform.deactivations, deactivationCount, "the delayed local pause must not end resumed group audio")
    XCTAssertEqual(player.playCalls.count, playCount + 1, "only the simulated remote play reached the engine")
    XCTAssertEqual(player.seekTargets.count, seekCount)
    XCTAssertEqual(SleepTimer.shared.state, .off)
    XCTAssertEqual(player.volume, Constants.Volume.boosted)
  }

  func testARemotePauseEndsWhatAPlayStartedWithoutPausingTheEngineAgain() async throws {
    try await loadAndPlay(singleFileBook(currentTime: 30))
    sut.setPlaybackCoordination(TestPlaybackCoordination())
    await settle()
    let paused = posts(of: .bookPaused)
    let deactivations = platform.deactivations

    player.pause()
    await settle()

    XCTAssertEqual(paused.count, 1)
    XCTAssertEqual(player.pauseCalls, 1, "a pause of ours would be sent back to the group")
    XCTAssertEqual(platform.deactivations, deactivations, "the group can resume at any moment")
    let recorded = libraryService.recordTimeCallsCount
    player.fireTick()
    XCTAssertEqual(libraryService.recordTimeCallsCount, recorded, "no listening time while the group is paused")

    postInterruption(.ended, options: .shouldResume)
    await settle()
    XCTAssertEqual(player.playCalls.count, 1, "an interruption ending must not resume a group that paused")
  }

  func testOurOwnPlayAndPauseAreNotRepeatedAsTheGroups() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    item.become(.readyToPlay)
    await settle()
    let coordination = TestPlaybackCoordination()
    sut.setPlaybackCoordination(coordination)
    let played = posts(of: .bookPlayed)
    let paused = posts(of: .bookPaused)

    sut.play()
    await waitUntil("playback starts") { self.player.playCalls.count == 1 }
    await settle()
    XCTAssertEqual(played.count, 1)
    XCTAssertEqual(coordination.activations, 0, "the play activated the session through the platform")

    postInterruption(.began)
    await settle()
    XCTAssertEqual(paused.count, 1)

    postInterruption(.ended, options: .shouldResume)
    await waitUntil("the interruption's end still resumes our own pause") { self.player.playCalls.count == 2 }
  }

  func testTheGroupsMoveToTheFileStartIsNotUndoneAsAClockFault() async throws {
    try await loadAndPlay(singleFileBook(currentTime: 40))
    sut.setPlaybackCoordination(TestPlaybackCoordination())
    await settle()
    let seeks = player.seekTargets

    player.reportedTime = 0.2
    player.fireTick()
    await settle()

    XCTAssertEqual(player.seekTargets, seeks, "a seek back to our position would move every participant")
    XCTAssertEqual(sut.currentItem?.currentTime, 0.2)
  }

  func testAPlayDoesNotPutOurPositionBackOverTheGroups() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(currentTime: 40), intent: .idle)
    item.become(.readyToPlay)
    await settle()
    sut.setPlaybackCoordination(TestPlaybackCoordination())
    let seeks = player.seekTargets

    /// The group is at the start, and no tick has reported it yet
    player.reportedTime = 0
    sut.play()
    await waitUntil("coordinated playback starts") { self.player.playCalls.count == 1 }
    await settle()

    XCTAssertEqual(player.seekTargets, seeks)
  }

  func testAQueuedRemoteResumeDoesNotReactivateAfterAPause() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    item.become(.readyToPlay)
    await settle()
    let coordination = TestPlaybackCoordination()
    sut.setPlaybackCoordination(coordination)

    player.playImmediately(atRate: 1)
    player.pause()
    await settle()

    XCTAssertEqual(coordination.activations, 0)
  }

  func testAQueuedRemoteResumeDoesNotReactivateAfterCoordinationEnds() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    item.become(.readyToPlay)
    await settle()
    let coordination = TestPlaybackCoordination()
    sut.setPlaybackCoordination(coordination)

    player.playImmediately(atRate: 1)
    sut.setPlaybackCoordination(nil)
    await settle()

    XCTAssertEqual(coordination.activations, 0)
    XCTAssertNil(player.playbackCoordinator.delegate)
  }

  func testSmartRewindIsSkippedWhileCoordinatedAndRestoredAfterLeaving() async throws {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    UserDefaults.standard.set(30.0, forKey: Constants.UserDefaults.smartRewindMaxInterval)
    let item = try await loadUntilInPlayer(singleFileBook(currentTime: 30), intent: .idle)
    item.become(.readyToPlay)
    await settle()
    sut.setPlaybackCoordination(TestPlaybackCoordination())
    sut.currentItem?.lastPlayDate = Date().addingTimeInterval(-86_400)
    let initialSeeks = player.seekTargets

    sut.play()
    await waitUntil("coordinated playback starts") { self.player.playCalls.count == 1 }
    await settle()
    XCTAssertEqual(player.seekTargets, initialSeeks, "local smart rewind would seek the whole group")

    sut.pause()
    sut.setPlaybackCoordination(nil)
    sut.currentItem?.lastPlayDate = Date().addingTimeInterval(-86_400)
    sut.play()
    await waitUntil("ordinary playback resumes") { self.player.playCalls.count == 2 }
    await settle()
    XCTAssertEqual(player.seekTargets.count, initialSeeks.count + 1)
    XCTAssertLessThan(try XCTUnwrap(player.seekTargets.last), 30)
  }

  func testRemoteRateIsSessionOnlyIncludingDuringAnInFlightSeek() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(currentTime: 30), intent: .idle)
    item.become(.readyToPlay)
    await settle()
    sut.setPlaybackCoordination(TestPlaybackCoordination())
    player.rate = 1.5
    sut.updateTime()
    XCTAssertEqual(sut.currentSpeed, 1.5)

    player.landsSeeksImmediately = false
    sut.jumpTo(10, recordBookmark: false)
    let expectedTime = try XCTUnwrap(sut.currentItem).currentTime
    player.rate = 2
    sut.updateTime()
    XCTAssertEqual(sut.currentSpeed, 2, "a pending seek must not suppress group-rate reconciliation")
    XCTAssertEqual(sut.currentItem?.currentTime, expectedTime, "the old engine position must not overwrite the seek target")
    XCTAssertEqual(player.reportedTime, 30)
    XCTAssertFalse(speedService.setSpeedRelativePathCalled)
    player.finishSeek()
    await settle()

    player.rate = 0
    sut.updateTime()
    XCTAssertEqual(sut.currentSpeed, 2, "a group pause is not a new playback speed")
    sut.setPlaybackCoordination(nil)
    XCTAssertEqual(sut.currentSpeed, 1, "the saved speed comes back with the session gone")
    XCTAssertEqual(player.rate, 0, "and leaves a paused player paused")
    player.rate = 3
    sut.updateTime()
    XCTAssertEqual(sut.currentSpeed, 1, "an uncoordinated engine rate must not replace the user's speed")
    XCTAssertFalse(speedService.setSpeedRelativePathCalled)
  }

  func testTheGroupsSpeedStaysThroughAVolumesFilesAndTheSavedOneReturnsOnLeaving() async throws {
    let first = try await loadAndPlay(boundBook())
    sut.setPlaybackCoordination(TestPlaybackCoordination())
    player.rate = 1.5
    sut.updateTime()
    XCTAssertEqual(sut.currentSpeed, 1.5)

    player.reportedTime = 50
    player.stopAtItemEnd()
    NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: first)
    let second = try await nextItemInPlayer(after: 1)
    second.become(.readyToPlay)
    await waitUntil("the next file plays") { self.player.playCalls.count == 2 }

    XCTAssertEqual(player.playCalls.last, 1.5, "a play at the saved speed would change every participant's")
    XCTAssertEqual(sut.currentSpeed, 1.5)

    sut.setPlaybackCoordination(nil)
    XCTAssertEqual(sut.currentSpeed, 1)
    XCTAssertEqual(player.rate, 1, "playback goes on at the saved speed")
    XCTAssertFalse(speedService.setSpeedRelativePathCalled, "the group's speed was never saved")
  }

  func testClaimingNowPlayingIsSkippedInAGroup() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    item.become(.readyToPlay)
    await settle()
    sut.setPlaybackCoordination(TestPlaybackCoordination())

    XCTAssertFalse(sut.claimNowPlayingThenPause(), "its muted play and pause would reach every participant")
    await settle()
    XCTAssertTrue(player.playCalls.isEmpty)
  }

  func testBoundBookCoordinationUsesFileOrdinalsAndNotChapterOrdinals() {
    let book = nestedVolume()
    var attachments = 0
    let coordination = SharePlayPlaybackCoordination(
      contentIdentifier: "shared-book", relativePath: book.relativePath,
      currentItem: { book }, coordinateSession: { _ in attachments += 1 }
    )
    let coordinator = player.playbackCoordinator
    coordination.coordinate(coordinator)
    XCTAssertEqual(attachments, 1)
    XCTAssertTrue(coordinator.delegate === coordination)
    for (index, chapter) in book.chapters.enumerated() {
      let item = AVPlayerItem(asset: AVURLAsset(url: chapter.fileURL))
      coordination.prepareForPlayback(of: item)
      XCTAssertEqual(
        coordination.playbackCoordinator(coordinator, identifierFor: item),
        "shared-book|file:\(index == 0 ? 0 : 1)"
      )
    }
    coordination.stopCoordinating(coordinator)
    XCTAssertNil(coordinator.delegate)
  }

  func testContentOutsideTheSessionsBookMatchesNoParticipants() {
    var current: PlayableItem? = singleFileBook("different.m4b")
    let coordination = SharePlayPlaybackCoordination(
      contentIdentifier: BookFingerprint(from: current!).identifier, relativePath: "matched.m4b",
      currentItem: { current }, coordinateSession: { _ in }
    )
    let other = SharePlayPlaybackCoordination(
      contentIdentifier: "shared-book", relativePath: "matched.m4b",
      currentItem: { current }, coordinateSession: { _ in }
    )
    let item = AVPlayerItem(asset: AVURLAsset(url: URL(fileURLWithPath: "/unmatched/audio.m4b")))
    let coordinator = player.playbackCoordinator
    coordination.prepareForPlayback(of: item)
    other.prepareForPlayback(of: item)

    let identifier = coordination.playbackCoordinator(coordinator, identifierFor: item)
    XCTAssertNotEqual(
      identifier, BookFingerprint(from: current!).identifier,
      "another book with the group's fingerprint must not report the group's identity"
    )
    XCTAssertNotEqual(identifier, other.playbackCoordinator(coordinator, identifierFor: item), "nor any device's")

    current = nil
    coordination.prepareForPlayback(of: item)
    XCTAssertEqual(coordination.playbackCoordinator(coordinator, identifierFor: item), identifier)
    let unprepared = AVPlayerItem(asset: AVURLAsset(url: URL(fileURLWithPath: "/unprepared/audio.m4b")))
    XCTAssertEqual(coordination.playbackCoordinator(coordinator, identifierFor: unprepared), identifier)
  }

  func testCoordinationRefreshesIdentityWhenTheBookChangesWithoutReloadingThePlayer() async throws {
    let matched = singleFileBook("matched.m4b")
    let item = try await loadUntilInPlayer(matched, intent: .idle)
    item.become(.readyToPlay)
    await settle()
    let coordination = SharePlayPlaybackCoordination(
      contentIdentifier: "shared-book", relativePath: matched.relativePath,
      currentItem: { [weak sut] in sut?.currentItem }, coordinateSession: { _ in }
    )
    sut.setPlaybackCoordination(coordination)
    let coordinator = player.playbackCoordinator
    let replacements = player.replacedItems.count
    XCTAssertEqual(coordination.playbackCoordinator(coordinator, identifierFor: item), "shared-book")

    /// The book rebuilt from the library, as after its chapters are re-parsed
    sut.currentItem = singleFileBook("matched.m4b")
    XCTAssertEqual(coordination.playbackCoordinator(coordinator, identifierFor: item), "shared-book")

    sut.currentItem = singleFileBook("different.m4b")
    XCTAssertNotEqual(coordination.playbackCoordinator(coordinator, identifierFor: item), "shared-book")
    XCTAssertEqual(player.replacedItems.count, replacements, "identity refresh doesn't require replacing the player item")
  }

  func testCoordinationIdentityCanBeReadOffTheMainActor() async {
    let book = nestedVolume()
    let coordination = SharePlayPlaybackCoordination(
      contentIdentifier: "shared-book", relativePath: book.relativePath,
      currentItem: { book }, coordinateSession: { _ in }
    )
    let coordinator = player.playbackCoordinator
    let item = AVPlayerItem(asset: AVURLAsset(url: book.chapters[1].fileURL))
    coordination.prepareForPlayback(of: item)
    let identifier = await Task.detached {
      coordination.playbackCoordinator(coordinator, identifierFor: item)
    }.value
    XCTAssertEqual(identifier, "shared-book|file:1")
  }

  // MARK: - 1–5: loading and queued playback

  /// Scenario 1
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
  func testALaunchPreloadRestoresThePositionWithoutPlaying() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(currentTime: 30), intent: .idle)

    XCTAssertEqual(player.seekTargets, [30])

    item.become(.readyToPlay)
    await settle()

    XCTAssertTrue(player.playCalls.isEmpty)
  }

  /// Scenario 3: play pressed while the item is still loading
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
  func testPausingDuringALoadKeepsItSilentOnceReady() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .wantsToPlay(.user))

    sut.pause()
    item.become(.readyToPlay)
    await settle()

    XCTAssertTrue(player.playCalls.isEmpty)
    XCTAssertFalse(item.isStatusObserved)
  }

  /// Scenario 5
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
  func testAnInterruptionPausesThenResumesAsAnAutomaticPlay() async throws {
    try await loadAndPlay(singleFileBook())

    postInterruption(.began)
    XCTAssertEqual(player.pauseCalls, 1)

    postInterruption(.ended, options: .shouldResume)
    await waitUntil("playback resumes") { self.player.playCalls.count == 2 }
  }

  /// Scenario 9: the reset makes a new player, and the next play loads the book into it where it was
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
  func testAVolumeMovesToTheNextFileWhenOneEnds() async throws {
    let first = try await loadAndPlay(boundBook())

    NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: first)
    let second = try await nextItemInPlayer(after: 1)

    XCTAssertEqual(sut.currentItem?.currentChapter.index, 2)

    second.become(.readyToPlay)
    await waitUntil("the next file plays") { self.player.playCalls.count == 2 }
  }

  /// Scenario 10, the last file
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
  func testTheChapterEndsOfTheFileInThePlayerAreObserved() async throws {
    _ = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    XCTAssertEqual(player.boundaryTimes, [50])

    /// A volume of one-chapter files: each ends with its file
    _ = try await loadUntilInPlayer(boundBook(), intent: .idle)
    XCTAssertEqual(player.boundaryTimes, [])
  }

  /// Scenario 11 inside a volume's file that holds two chapters: its times count from the file's start
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
  func testAManualPlayArmsTheRememberedTimer() async throws {
    rememberEndOfChapterTimer()
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    item.become(.readyToPlay)

    sut.play()
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }

    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter)
  }

  /// Scenario 12, a tap on a new book in the library: the play starts once its item loads
  func testANewBookTapArmsTheRememberedTimer() async throws {
    rememberEndOfChapterTimer()

    try await loadAndPlay(singleFileBook())

    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter)
  }

  /// Scenario 12, play pressed while the item is still loading: still the user's play once it starts
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
  func testTheNextBookAfterAFinishedOneDoesNotArmTheRememberedTimer() async throws {
    platform.autoplaysNextBook = true
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
  func testAnInterruptionsResumeDoesNotArmTheRememberedTimer() async throws {
    rememberEndOfChapterTimer()
    try await loadAndPlay(singleFileBook(), origin: .system)

    postInterruption(.began)
    postInterruption(.ended, options: .shouldResume)
    await waitUntil("playback resumes") { self.player.playCalls.count == 2 }

    XCTAssertEqual(SleepTimer.shared.state, .off)
  }

  /// Scenario 12, CarPlay connecting: the muted play that claims Now Playing, then pauses
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

  // MARK: - The load's states

  /// A volume's next file chosen while the current one is still loading: the new item is observed, and
  /// the queued play starts once it's ready. Before rework PR 5 a leftover `observeStatus` left it unobserved
  func testAChapterChangeDuringALoadObservesTheNewItem() async throws {
    let first = try await loadUntilInPlayer(boundBook(), intent: .wantsToPlay(.user))
    let nextChapter = try XCTUnwrap(sut.currentItem?.chapters.last)

    sut.jumpToChapter(nextChapter)
    let second = try await nextItemInPlayer(after: 1)

    XCTAssertFalse(first.isStatusObserved)
    XCTAssertTrue(second.isStatusObserved)

    second.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }
    await settle()

    XCTAssertEqual(player.playCalls.count, 1)
  }

  /// Play pressed while the file is still being found (its media server hasn't answered): it waits for
  /// that load instead of starting another
  func testPlayPressedWhileResolvingWaitsForThatLoad() async throws {
    let server = HeldStreamLookup()
    sut = makeManager(streamLookup: server)
    sut.load(lookedUpBook(), intent: .idle)
    await waitUntil("the server is asked") { server.isAsked }

    sut.play()
    await settle()
    XCTAssertTrue(items.isEmpty, "nothing reaches the engine before the server answers")

    server.answer(.answered([lookedUpFile]))
    let item = try await nextItemInPlayer(after: 0)
    item.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }
    await settle()

    XCTAssertEqual(server.calls, 1, "the play doesn't ask again")
    XCTAssertEqual(items.count, 1, "one load")
    XCTAssertEqual(player.playCalls.count, 1)
  }

  /// A pause while the file is still being found cancels that load, and the next play loads the book again
  func testAPauseWhileResolvingCancelsTheLoad() async throws {
    let server = HeldStreamLookup()
    sut = makeManager(streamLookup: server)
    sut.load(lookedUpBook(), intent: .wantsToPlay(.user))
    await waitUntil("the server is asked") { server.isAsked }

    sut.pause()
    server.answer(.answered([lookedUpFile]))
    await settle()
    XCTAssertTrue(items.isEmpty, "the cancelled load doesn't reach the engine")

    sut.play()
    await waitUntil("the server is asked again") { server.isAsked }
    server.answer(.answered([lookedUpFile]))
    let item = try await nextItemInPlayer(after: 0)
    item.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }

    XCTAssertEqual(server.calls, 2)
  }

  /// An item that's ready before its status is observed still reports, through the initial value
  func testAnItemAlreadyReadyStillReports() async throws {
    sut = makeManager(makeItem: { asset in
      let item = ControlledPlayerItem(asset: asset)
      item.become(.readyToPlay)
      return item
    })

    sut.load(singleFileBook(), intent: .wantsToPlay(.user))
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }
    await settle()

    XCTAssertEqual(player.playCalls.count, 1)
    XCTAssertFalse(try XCTUnwrap(items.first).isStatusObserved)
  }

  /// Only the player's own item ending counts: another item's end, such as the file it held before,
  /// leaves the book where it is
  func testAnotherItemsEndIsIgnored() async throws {
    let first = try await loadAndPlay(boundBook())
    NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: first)
    let second = try await nextItemInPlayer(after: 1)
    XCTAssertEqual(sut.currentItem?.currentChapter.index, 2)

    /// The first file again, and an item no player holds
    NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: first)
    NotificationCenter.default.post(
      name: .AVPlayerItemDidPlayToEndTime,
      object: AVPlayerItem(url: URL(fileURLWithPath: "/dev/null"))
    )
    await settle()

    XCTAssertEqual(sut.currentItem?.currentChapter.index, 2)
    XCTAssertEqual(libraryService.markAsFinishedFlagRelativePathCallsCount, 0, "the book isn't finished")
    XCTAssertEqual(items.count, 2, "nothing else loads")
    XCTAssertTrue(player.currentItem === second)
  }

  /// A load that failed and was reported: the next play loads the book again, and plays it
  func testAFailedLoadReloadsOnTheNextPlay() async throws {
    let first = try await loadUntilInPlayer(singleFileBook(), intent: .wantsToPlay(.user))
    first.become(.failed, error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotDecodeContentData))
    await waitUntil("the failure is reported") { !self.failures.isEmpty }

    sut.play()
    let second = try await nextItemInPlayer(after: 1)
    second.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }

    XCTAssertEqual(failures.count, 1)
    XCTAssertTrue(player.currentItem === second)
  }

  /// A stream can fail after it was ready, mid-playback: nothing reports it then, and the next play loads
  /// the book again instead of playing the failed item
  func testAnItemThatFailsAfterItWasReadyReloadsOnTheNextPlay() async throws {
    let first = try await loadAndPlay(streamedBook())
    first.become(.failed, error: NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost))
    sut.pause()
    await settle()
    XCTAssertTrue(failures.isEmpty)

    sut.play()
    let second = try await nextItemInPlayer(after: 1)
    second.become(.readyToPlay)
    await waitUntil("playback starts again") { self.player.playCalls.count == 2 }

    XCTAssertTrue(player.currentItem === second)
  }

  /// The silent reloads come back with each play asked for, and only then
  func testThePlayRefillsTheRetryBudget() async throws {
    let unavailable = NSError(domain: NSURLErrorDomain, code: NSURLErrorResourceUnavailable)
    let first = try await loadUntilInPlayer(singleFileBook(), intent: .wantsToPlay(.user))
    first.become(.failed, error: unavailable)
    let second = try await nextItemInPlayer(after: 1)
    second.become(.failed, error: unavailable)
    await waitUntil("the failure is reported") { self.failures.count == 1 }

    /// The tap after the alert: its load gets a silent reload again
    sut.play()
    let third = try await nextItemInPlayer(after: 2)
    third.become(.failed, error: unavailable)
    let fourth = try await nextItemInPlayer(after: 3)
    await settle()

    XCTAssertEqual(failures.count, 1, "the reload after the tap is silent")
    fourth.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }
  }

  func testAwaitingALoadWaitsForTheItemItselfNotForBookReady() async throws {
    let ready = expectation(forNotification: .bookReady, object: nil)
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    var outcome: Bool?
    let waiting = Task { outcome = await self.sut.awaitItemLoad() }
    await fulfillment(of: [ready], timeout: 2)
    await settle()
    XCTAssertNil(outcome, "the file reached the engine, which hasn't opened it yet")

    item.become(.readyToPlay)
    await waiting.value

    XCTAssertEqual(outcome, true)
    XCTAssertTrue(player.playCalls.isEmpty)
  }

  func testAwaitingALoadFollowsItsReloadAndEndsOnTheFailure() async throws {
    let unavailable = NSError(domain: NSURLErrorDomain, code: NSURLErrorResourceUnavailable)
    let first = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    var outcome: Bool?
    let waiting = Task { outcome = await self.sut.awaitItemLoad() }

    first.become(.failed, error: unavailable)
    let second = try await nextItemInPlayer(after: 1)
    await settle()
    XCTAssertNil(outcome, "the reload is the same load")

    second.become(.failed, error: unavailable)
    await waiting.value

    XCTAssertEqual(outcome, false)
  }

  func testAwaitingALoadEndsWithItsTaskWhileTheLoadGoesOn() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    let waiting = Task { await self.sut.awaitItemLoad() }
    await settle()

    waiting.cancel()
    let outcome = await waiting.value
    XCTAssertFalse(outcome, "a cancelled wait must not stay suspended until the load settles")

    item.become(.readyToPlay)
    let loaded = await sut.awaitItemLoad()
    XCTAssertTrue(loaded, "the load itself wasn't cancelled")
  }

  func testAwaitingALoadGivesUpOnOneThatStalls() async throws {
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .idle)

    let stalled = await sut.awaitItemLoad(timeout: 0.05)
    XCTAssertFalse(stalled)

    item.become(.readyToPlay)
    let loaded = await sut.awaitItemLoad(timeout: 0.05)
    XCTAssertTrue(loaded)
  }

  func testAwaitingALoadEndsWhenItIsDropped() async throws {
    let none = await sut.awaitItemLoad()
    XCTAssertFalse(none, "nothing is loading")

    _ = try await loadUntilInPlayer(singleFileBook(), intent: .idle)
    let waiting = Task { await self.sut.awaitItemLoad() }
    await settle()
    sut.stop()

    let outcome = await waiting.value
    XCTAssertFalse(outcome)
  }

  // MARK: - The platform

  /// The platform couldn't activate the audio session: the play stops there, and isn't left pending
  func testAFailedActivationStopsThePlay() async throws {
    platform.activates = false
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .wantsToPlay(.user))

    item.become(.readyToPlay)
    await waitUntil("the session is asked for") { self.platform.activations == 1 }
    await settle()

    XCTAssertTrue(player.playCalls.isEmpty)
    XCTAssertFalse(sut.isPlaying)
  }

  /// A pause while the platform is still activating the audio session (the watch's route picker) wins: the
  /// play doesn't start once the activation finishes
  func testAPauseDuringActivationStopsThePlay() async throws {
    platform.holdsActivation = true
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .wantsToPlay(.user))
    item.become(.readyToPlay)
    await waitUntil("the session is asked for") { self.platform.activations == 1 }

    sut.pause()
    platform.finishActivation()
    await settle()

    XCTAssertTrue(player.playCalls.isEmpty)
    XCTAssertFalse(sut.isPlaying)
  }

  /// The pause ends the session 0.1 s later, before a route picker is done: an activation that finishes
  /// after it ends the session again, rather than leave it on with nothing playing
  func testAnActivationFinishingAfterAPauseEndsTheSession() async throws {
    platform.holdsActivation = true
    let item = try await loadUntilInPlayer(singleFileBook(), intent: .wantsToPlay(.user))
    item.become(.readyToPlay)
    await waitUntil("the session is asked for") { self.platform.activations == 1 }

    sut.pause()
    await waitUntil("the pause ends the session") { self.platform.deactivations == 1 }
    platform.finishActivation()

    await waitUntil("the finished activation ends it") { self.platform.deactivations == 2 }
    XCTAssertTrue(player.playCalls.isEmpty)
  }

  // MARK: - A finished book

  /// The user's play on a book that played to its end, still loaded, starts it over from the first chapter
  func testPlayingAFinishedBookStartsItOver() async throws {
    let first = try await loadAndPlay(singleFileBook(currentTime: 60))
    try await playToTheEnd(first)

    sut.play()
    let restarted = try await nextItemInPlayer(after: 1)
    /// A new item starts at its beginning
    player.reportedTime = 0
    restarted.become(.readyToPlay)
    await waitUntil("the book plays again") { self.player.playCalls.count == 2 }

    XCTAssertEqual(sut.currentItem?.currentTime, 0)
    XCTAssertEqual(sut.currentItem?.currentChapter.index, 1)
  }

  /// A play the system makes on a finished book (an interruption ending) leaves it at its end
  func testASystemPlayOnAFinishedBookStaysAtTheEnd() async throws {
    let first = try await loadAndPlay(singleFileBook(currentTime: 60))
    try await playToTheEnd(first)

    sut.play(origin: .system)
    await settle()

    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(player.playCalls.count, 1)
    XCTAssertFalse(sut.isPlaying)
  }

  /// The platform says whether the next book plays when one ends, and whether a finished one starts over
  func testTheNextBookFollowsThePlatformsAutoplaySettings() async throws {
    platform.autoplaysNextBook = true
    platform.restartsFinishedBooks = true
    playbackService.getPlayableItemAfterParentFolderAutoplayedRestartFinishedReturnValue = singleFileBook("next.m4b")
    let first = try await loadAndPlay(singleFileBook(currentTime: 60))

    try await playToTheEnd(first)
    _ = try await nextItemInPlayer(after: 1)

    let lookup = try XCTUnwrap(playbackService.getPlayableItemAfterParentFolderAutoplayedRestartFinishedReceivedArguments)
    XCTAssertTrue(lookup.autoplayed)
    XCTAssertTrue(lookup.restartFinished)
    XCTAssertEqual(sut.currentItem?.relativePath, "next.m4b")
  }

  /// With autoplay off, a book ending doesn't look for the next one
  func testTheNextBookWaitsWhenThePlatformDoesNotAutoplay() async throws {
    playbackService.getPlayableItemAfterParentFolderAutoplayedRestartFinishedReturnValue = singleFileBook("next.m4b")
    let first = try await loadAndPlay(singleFileBook(currentTime: 60))

    try await playToTheEnd(first)
    await settle()

    XCTAssertFalse(playbackService.getPlayableItemAfterParentFolderAutoplayedRestartFinishedCalled)
    XCTAssertEqual(sut.currentItem?.relativePath, "book.m4b")
    XCTAssertEqual(items.count, 1)
  }

  /// After the end-of-chapter timer pauses, a shake resumes playback and re-arms the timer: the platform
  /// listens for it, and a play stops listening
  func testAShakeAfterTheTimerResumesPlayback() async throws {
    try await loadAndPlay(singleFileBook())
    XCTAssertEqual(platform.shakeStops, 1, "a play stops listening for the shake")
    SleepTimer.shared.setTimer(.endOfChapter)

    player.crossBoundary(at: 50)
    XCTAssertEqual(player.pauseCalls, 1)
    let shake = try XCTUnwrap(platform.shakeHandler, "the timer's pause listens for a shake")

    shake()
    await waitUntil("playback resumes") { self.player.playCalls.count == 2 }

    XCTAssertEqual(SleepTimer.shared.state, .endOfChapter)
    XCTAssertEqual(platform.shakeStops, 2)
  }

  /// A finished book's folder progress waits for the app's foreground when the platform says so, and is
  /// updated right away otherwise
  func testFolderProgressWaitsWhenThePlatformDefersIt() {
    sut.currentItem = book("folder/book.m4b", chapters: [chapter(1, start: 0, duration: 50, relativePath: "folder/book.m4b")], parentFolder: "folder")

    platform.defersFolderProgress = true
    sut.markAsCompleted(true)

    XCTAssertEqual(playbackService.markStaleProgressFolderPathReceivedInvocations, ["folder"])
    XCTAssertEqual(libraryService.recursiveFolderProgressUpdateFromCallsCount, 0)

    platform.defersFolderProgress = false
    sut.markAsCompleted(true)

    XCTAssertEqual(libraryService.recursiveFolderProgressUpdateFromReceivedInvocations, ["folder"])
    XCTAssertEqual(playbackService.markStaleProgressFolderPathCallsCount, 1)
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
    isBoundBook: Bool = false,
    parentFolder: String? = nil
  ) -> PlayableItem {
    PlayableItem(
      title: relativePath,
      author: "author",
      chapters: chapters,
      currentTime: currentTime,
      duration: chapters.map(\.end).max() ?? 0,
      relativePath: relativePath,
      uuid: "LEGACY_UUID",
      parentFolder: parentFolder,
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

  /// An AudiobookShelf book: its server is asked for the file when it loads, and nothing is on disk
  private func lookedUpBook() -> PlayableItem {
    book(
      "looked-up.mp3",
      chapters: [
        PlayableChapter(
          title: "chapter 1",
          author: "author",
          start: 0,
          duration: 100,
          relativePath: "looked-up.mp3",
          remoteURL: nil,
          externalURL: nil,
          index: 1,
          externalHeaders: ["Authorization": "Bearer t"],
          streamLookup: PlayableChapter.StreamLookup(
            serverURL: URL(string: "https://abs.example.com")!,
            itemId: "li_1",
            member: .item
          )
        )
      ]
    )
  }

  /// The one file `lookedUpBook`'s server lists
  private let lookedUpFile = ExternalStreamFile(path: "api/items/li_1/file/1", name: "01.mp3", duration: 100)

  // MARK: - Driving the manager

  /// Loads `book` and returns its item once `PlayerManager` has handed it to the player
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

  /// Plays `item`, a single-file book's, to its end: the clock at the book's length, then the item's end
  private func playToTheEnd(_ item: ControlledPlayerItem) async throws {
    let duration = try XCTUnwrap(sut.currentItem?.duration)
    player.reportedTime = duration
    player.stopAtItemEnd()
    NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: item)
    await waitUntil("the book is finished") { self.libraryService.markAsFinishedFlagRelativePathCalled }
  }

  /// Waits for an item beyond the first `count` to reach the player
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

  /// Lets the load's hops (a `Task`, `DispatchQueue.main`) run until `condition` holds
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

  /// Counts the posts of `name` from now on, keeping the book each carries
  private func posts(of name: Notification.Name) -> NotificationPosts {
    NotificationPosts(of: name)
  }

  /// The auto timer on, with the end-of-chapter timer as the one it remembers but not running
  private func rememberEndOfChapterTimer() {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.autoTimerEnabled)
    SleepTimer.shared.setTimer(.endOfChapter)
    /// Ends it the way a chapter change does, which keeps it as the remembered one
    NotificationCenter.default.post(name: .chapterChange, object: nil)
  }
}

/// The posts of one notification while it's held
private final class NotificationPosts {
  private(set) var count = 0
  private(set) var books: [PlayableItem] = []
  private var observer: NSObjectProtocol?

  init(of name: Notification.Name) {
    observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] post in
      self?.count += 1
      if let book = post.userInfo?["book"] as? PlayableItem {
        self?.books.append(book)
      }
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }
}

/// Exercises core coordination without a live GroupSession or real audio-session activation.
@MainActor
private final class TestPlaybackCoordination: NSObject, PlaybackCoordinating, AVPlayerPlaybackCoordinatorDelegate {
  private(set) var attached: [AVPlayerPlaybackCoordinator] = []
  private(set) var detached: [AVPlayerPlaybackCoordinator] = []
  private(set) var activations = 0

  func prepareForPlayback(of playerItem: AVPlayerItem?) {}

  func coordinate(_ coordinator: AVPlayerPlaybackCoordinator) {
    attached.append(coordinator)
    coordinator.delegate = self
  }

  func stopCoordinating(_ coordinator: AVPlayerPlaybackCoordinator) {
    detached.append(coordinator)
    coordinator.delegate = nil
  }

  func activateAudioSession() {
    activations += 1
  }

  nonisolated func playbackCoordinator(_ coordinator: AVPlayerPlaybackCoordinator, identifierFor playerItem: AVPlayerItem) -> String {
    "test-book"
  }
}

/// A media server that answers when the test says so, holding a load in `.resolving` until then
@MainActor
private final class HeldStreamLookup: ExternalStreamLooking {
  private var pending: CheckedContinuation<ExternalStreamFiles, Never>?
  private(set) var calls = 0

  /// A lookup is waiting for its answer
  var isAsked: Bool { pending != nil }

  func files(
    ofItem itemId: String,
    on serverURL: URL,
    headers: [String: String],
    timeout: TimeInterval
  ) async -> ExternalStreamFiles {
    calls += 1
    return await withCheckedContinuation { pending = $0 }
  }

  func answer(_ files: ExternalStreamFiles) {
    let waiting = pending
    pending = nil
    waiting?.resume(returning: files)
  }
}
