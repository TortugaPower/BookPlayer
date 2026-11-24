//
//  PlayerManagerPlayTimeCheckTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import CoreData
import Foundation
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// The play-time check as a play starts: a play the user asked for asks the server about its book first, for
/// at most `serverWaitLimit` together with the list's fetch, and starts where another device stopped when that
/// device played it since. An answer after the limit moves the book mid-playback. Whether the server's play is
/// newer is `SyncService`'s call (`PlayTimeCheckTests`); here the mock answers it.
@MainActor
final class PlayerManagerPlayTimeCheckTests: XCTestCase {
  /// A server answer the test gives when it says so
  @MainActor
  private final class HeldAnswer {
    private var continuation: CheckedContinuation<Bool, Never>?

    func wait() async -> Bool {
      await withCheckedContinuation { continuation = $0 }
    }

    func give(_ adopted: Bool) {
      continuation?.resume(returning: adopted)
      continuation = nil
    }
  }

  /// A list fetch that runs until the test finishes it
  @MainActor
  private final class HeldFetch: PlaybackSyncProgressDelegate {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var isWaitedOn = false

    func waitForSyncInProgress() async {
      isWaitedOn = true
      await withCheckedContinuation { continuation = $0 }
    }

    func finish() {
      continuation?.resume()
      continuation = nil
    }
  }

  private var libraryService: LibraryServiceProtocolMock!
  private var playbackService: PlaybackServiceProtocolMock!
  private var syncService: SyncServiceProtocolMock!
  private var platform: TestPlayerPlatform!
  private var coreDataStack: CoreDataStack!
  private var players: [ControlledPlayer] = []
  private var items: [ControlledPlayerItem] = []
  private var answer: HeldAnswer!
  private var fetch: HeldFetch!
  private var savedDefaults: [String: Any] = [:]
  private var sut: PlayerManager!

  private let uuid = UUID().uuidString
  /// On disk, so the load doesn't go looking for a cloud copy
  private var relativePath = ""
  /// When this device last played the book
  private let playedHere = Date(timeIntervalSince1970: 1_000_000)

  private var player: ControlledPlayer { players[players.count - 1] }

  /// Settings on the play path that move the player, restored after each test
  private let touchedDefaults = [
    Constants.UserDefaults.smartRewindEnabled,
    Constants.UserDefaults.autoTimerEnabled,
  ]

  override func setUpWithError() throws {
    try super.setUpWithError()
    for key in touchedDefaults {
      if let value = UserDefaults.standard.object(forKey: key) {
        savedDefaults[key] = value
      }
      UserDefaults.standard.removeObject(forKey: key)
    }

    relativePath = "play-time-check-\(UUID().uuidString).m4b"
    FileManager.default.createFile(atPath: fileURL.path, contents: Data())

    coreDataStack = CoreDataStack(testPath: "/dev/null")
    let context = coreDataStack.managedContext
    /// By entity name: each test loads the model again, so a lookup by class finds several matches
    let recordEntity = try XCTUnwrap(NSEntityDescription.entity(forEntityName: "PlaybackRecord", in: context))
    libraryService = LibraryServiceProtocolMock()
    libraryService.getCurrentPlaybackRecordReturnValue = PlaybackRecord(entity: recordEntity, insertInto: context)
    playbackService = PlaybackServiceProtocolMock()
    playbackService.updatePlaybackTimeItemTimeClosure = { item, time in
      item.currentTime = time
      item.lastPlayDate = Date()
    }

    syncService = SyncServiceProtocolMock()
    syncService.isActive = true
    syncService.adoptNewerPlayOfUuidPlayedAtReturnValue = false
    answer = HeldAnswer()
    fetch = HeldFetch()

    let speedService = SpeedServiceProtocolMock()
    speedService.getSpeedRelativePathReturnValue = 1
    platform = TestPlayerPlatform()
    platform.asksServerBeforePlaying = true

    sut = PlayerManager(
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService,
      speedService: speedService,
      platform: platform,
      widgetReloadService: WidgetReloadService(),
      hasStreamingEnabled: { false },
      presentFailure: { _ in },
      engine: AVPlayerEngine(
        makePlayer: { [unowned self] in
          let player = ControlledPlayer()
          self.players.append(player)
          return player
        },
        makePlayerItem: { [unowned self] asset in
          let item = ControlledPlayerItem(asset: asset)
          self.items.append(item)
          return item
        }
      )
    )
  }

  override func tearDown() {
    sut.stop()
    answer.give(false)
    fetch.finish()
    try? FileManager.default.removeItem(at: fileURL)

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
    savedDefaults = [:]
    super.tearDown()
  }

  // MARK: - Answered in time

  /// Tapping the book: another device played it since, so it starts where that device stopped, never from
  /// this device's older spot
  func testANewerPlayStartsWhereTheOtherDeviceStopped() async throws {
    syncService.adoptNewerPlayOfUuidPlayedAtClosure = { [unowned self] _, _, _ in
      self.libraryHolds(currentTime: 70)
      return true
    }

    let first = try await loadUntilInPlayer(book(currentTime: 10), intent: .wantsToPlay(.user))
    first.become(.readyToPlay)
    let second = try await nextItemInPlayer(after: 1)

    XCTAssertTrue(player.playCalls.isEmpty, "nothing plays from the older spot")
    XCTAssertEqual(player.seekTargets.last, 70)

    second.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }
    await settle()

    XCTAssertEqual(player.playCalls.count, 1)
    XCTAssertTrue(player.currentItem === second)
    XCTAssertEqual(syncService.adoptNewerPlayOfUuidPlayedAtCallsCount, 1, "starting there doesn't ask again")
    let asked = try XCTUnwrap(syncService.adoptNewerPlayOfUuidPlayedAtReceivedArguments)
    XCTAssertEqual(asked.relativePath, relativePath)
    XCTAssertEqual(asked.uuid, uuid)
    XCTAssertEqual(asked.lastPlayDate, playedHere)
  }

  /// Pressing play on the book already loaded: this device played it last (or in the same second), so it
  /// starts from here
  func testAPlayThatIsntNewerStartsFromHere() async throws {
    let item = try await loadUntilInPlayer(book(currentTime: 10), intent: .idle)
    item.become(.readyToPlay)
    await settle()

    sut.play()
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }
    await settle()

    XCTAssertEqual(items.count, 1, "nothing reloads")
    XCTAssertEqual(player.seekTargets, [10])
    XCTAssertEqual(syncService.adoptNewerPlayOfUuidPlayedAtCallsCount, 1)
    XCTAssertEqual(syncService.adoptNewerPlayOfUuidPlayedAtReceivedArguments?.lastPlayDate, playedHere)
  }

  /// Play pressed again while the book loads, after the load stamped it played now (as a cloud file's
  /// rebuilt item is): the check still compares with the play time from the first press
  func testASecondPressKeepsThePlayTimeOfTheFirst() async throws {
    let item = try await loadUntilInPlayer(book(), intent: .wantsToPlay(.user))
    sut.currentItem?.lastPlayDate = Date()

    sut.play()
    item.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }

    XCTAssertEqual(syncService.adoptNewerPlayOfUuidPlayedAtCallsCount, 1)
    XCTAssertEqual(syncService.adoptNewerPlayOfUuidPlayedAtReceivedArguments?.lastPlayDate, playedHere)
  }

  // MARK: - Answered late

  /// No answer within the limit: playback starts from here, then moves to the newer play once it comes
  func testALateNewerPlayMovesThePlaybackThere() async throws {
    sut.serverWaitLimit = .milliseconds(100)
    syncService.adoptNewerPlayOfUuidPlayedAtClosure = { [unowned self] _, _, _ in await self.answer.wait() }

    let first = try await loadUntilInPlayer(book(currentTime: 10), intent: .wantsToPlay(.user))
    first.become(.readyToPlay)
    await waitUntil("playback starts from here") { !self.player.playCalls.isEmpty }
    XCTAssertTrue(player.currentItem === first)

    libraryHolds(currentTime: 70)
    answer.give(true)
    let second = try await nextItemInPlayer(after: 1)
    XCTAssertEqual(player.seekTargets.last, 70)

    second.become(.readyToPlay)
    await waitUntil("playback goes on from the newer play") { self.player.playCalls.count == 2 }
    XCTAssertTrue(player.currentItem === second)
    XCTAssertEqual(syncService.adoptNewerPlayOfUuidPlayedAtCallsCount, 1)
  }

  /// A late answer that isn't newer leaves playback alone
  func testALateAnswerThatIsntNewerChangesNothing() async throws {
    sut.serverWaitLimit = .milliseconds(100)
    syncService.adoptNewerPlayOfUuidPlayedAtClosure = { [unowned self] _, _, _ in await self.answer.wait() }

    try await loadAndPlay(book(currentTime: 10))
    answer.give(false)
    await settle()

    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(player.playCalls.count, 1)
  }

  /// A list fetch still running holds the play only up to the limit too
  func testAListFetchHoldsThePlayOnlyUpToTheLimit() async throws {
    sut.serverWaitLimit = .milliseconds(100)
    sut.syncProgressDelegate = fetch
    let started = Date()

    try await loadAndPlay(book())

    XCTAssertTrue(fetch.isWaitedOn)
    XCTAssertLessThan(Date().timeIntervalSince(started), 1)
  }

  // MARK: - Not asked

  func testOfflineNothingIsAsked() async throws {
    platform.asksServerBeforePlaying = false

    try await loadAndPlay(book())

    XCTAssertFalse(syncService.adoptNewerPlayOfUuidPlayedAtCalled)
  }

  func testWithoutSyncNothingIsAsked() async throws {
    syncService.isActive = false

    try await loadAndPlay(book())

    XCTAssertFalse(syncService.adoptNewerPlayOfUuidPlayedAtCalled)
  }

  /// The player moving on by itself (the next book after one finished, `playNextItem(autoPlayed: true)`)
  func testAPlayTheSystemStartsAsksNothing() async throws {
    let item = try await loadUntilInPlayer(book(), intent: .wantsToPlay(.system))
    item.become(.readyToPlay)
    await waitUntil("playback starts") { !self.player.playCalls.isEmpty }

    XCTAssertFalse(syncService.adoptNewerPlayOfUuidPlayedAtCalled)
  }

  // MARK: - Helpers

  private var fileURL: URL {
    DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)
  }

  /// One 100 s chapter
  private func book(currentTime: TimeInterval = 0, lastPlayDate: Date? = nil) -> PlayableItem {
    PlayableItem(
      title: "Dune",
      author: "author",
      chapters: [
        PlayableChapter(
          title: "chapter 1",
          author: "author",
          start: 0,
          duration: 100,
          relativePath: relativePath,
          remoteURL: nil,
          externalURL: nil,
          index: 1
        )
      ],
      currentTime: currentTime,
      duration: 100,
      relativePath: relativePath,
      uuid: uuid,
      parentFolder: nil,
      percentCompleted: currentTime,
      lastPlayDate: lastPlayDate ?? playedHere,
      isFinished: false,
      isBoundBook: false
    )
  }

  /// The book's row once the check stored another device's newer play
  private func libraryHolds(currentTime: TimeInterval) {
    libraryService.getSimpleItemWithReturnValue = SimpleLibraryItem(
      title: "Dune",
      details: "author",
      speed: 1,
      currentTime: currentTime,
      duration: 100,
      percentCompleted: currentTime,
      isFinished: false,
      relativePath: relativePath,
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: relativePath,
      lastPlayDate: Date(timeIntervalSince1970: 1_000_500),
      type: .book,
      uuid: uuid
    )
    playbackService.getPlayableItemFromClosure = { [unowned self] row in
      self.book(currentTime: row.currentTime, lastPlayDate: row.lastPlayDate)
    }
  }

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

  /// Loads `book` as a tap in the library does, makes it ready and waits for playback to start
  @discardableResult
  private func loadAndPlay(
    _ book: PlayableItem,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async throws -> ControlledPlayerItem {
    let item = try await loadUntilInPlayer(book, intent: .wantsToPlay(.user), file: file, line: line)
    item.become(.readyToPlay)
    await waitUntil("playback starts", file: file, line: line) { !self.player.playCalls.isEmpty }
    return item
  }

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
}
