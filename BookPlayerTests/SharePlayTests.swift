//
//  SharePlayTests.swift
//  BookPlayerTests
//
//  Created by dawsonamf on 11/12/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import Foundation
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// How a shared book is recognised in the local library and brought into the player. A live
/// `GroupSession` can't be made in a test, so the session itself isn't covered here.
@MainActor
final class SharePlayTests: XCTestCase {
  private var libraryService: LibraryServiceProtocolMock!
  private var playbackService: PlaybackServiceProtocolMock!
  private var player: ControlledPlayer!
  private var items: [ControlledPlayerItem] = []
  private var playerManager: PlayerManager!
  private var sut: SharePlayService!
  /// The library `searchAllBooks` and `getPlayableItem(from:)` answer from, by relative path
  private var library: [String: PlayableItem] = [:]

  override func setUpWithError() throws {
    try super.setUpWithError()
    libraryService = LibraryServiceProtocolMock()
    libraryService.searchAllBooksQueryLimitOffsetClosure = { [unowned self] query, _, _ in
      self.library.values
        .filter { $0.title.lowercased().contains(query?.lowercased() ?? "") }
        .sorted { $0.relativePath < $1.relativePath }
        .map(self.libraryItem(for:))
    }
    playbackService = PlaybackServiceProtocolMock()
    playbackService.getPlayableItemFromClosure = { [unowned self] item in
      guard let book = self.library[item.relativePath] else {
        throw BPPlayerError.fileMissing(relativePath: item.relativePath)
      }
      return book
    }
    let syncService = SyncServiceProtocolMock()
    syncService.isActive = false
    let speedService = SpeedServiceProtocolMock()
    speedService.getSpeedRelativePathReturnValue = 1

    playerManager = PlayerManager(
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService,
      speedService: speedService,
      platform: TestPlayerPlatform(),
      widgetReloadService: WidgetReloadService(),
      hasStreamingEnabled: { false },
      presentFailure: { _ in },
      engine: AVPlayerEngine(
        makePlayer: { [unowned self] in
          self.player = ControlledPlayer()
          return self.player
        },
        makePlayerItem: { [unowned self] asset in
          let item = ControlledPlayerItem(asset: asset)
          self.items.append(item)
          return item
        }
      )
    )
    sut = SharePlayService(
      playerManager: playerManager,
      libraryService: libraryService,
      playbackService: playbackService
    )
  }

  override func tearDown() {
    sut.leaveSession()
    playerManager.stop()
    sut = nil
    playerManager = nil
    player = nil
    items = []
    library = [:]
    super.tearDown()
  }

  // MARK: - The fingerprint

  func testTheSameBookImportedTwiceHasOneFingerprint() {
    let sharer = book("a/Dune.m4b", title: "Dune", author: "Frank Herbert")
    let joiner = book("b/other-name.m4b", title: " dune\n", author: "FRANK HERBERT")

    XCTAssertEqual(BookFingerprint(from: sharer), BookFingerprint(from: joiner))
    XCTAssertEqual(BookFingerprint(from: sharer).identifier, "dune|frank herbert|100|2|1")
  }

  func testTheUnknownAuthorPlaceholderIsNoAuthor() {
    let unknown = book("Dune.m4b", title: "Dune", author: "voiceover_unknown_author".localized)

    XCTAssertEqual(BookFingerprint(from: unknown).authorNormalized, "")
    XCTAssertEqual(BookFingerprint(from: unknown), BookFingerprint(from: book("Dune.m4b", title: "Dune", author: "")))
  }

  func testAFingerprintCountsFilesNotChapters() {
    let volume = book("Dune", title: "Dune", files: ["Dune/1.mp3", "Dune/2.mp3", "Dune/2.mp3"])

    XCTAssertEqual(BookFingerprint(from: volume).chapterCount, 3)
    XCTAssertEqual(BookFingerprint(from: volume).fileCount, 2)
  }

  // MARK: - The matcher

  func testTheMatcherFindsTheSameBookUnderAnotherPath() {
    let matcher = BookLibraryMatcher(libraryService: libraryService, playbackService: playbackService)
    add(book("mine/Dune.m4b", title: "Dune", author: "Frank Herbert"))
    add(book("mine/Dune Messiah.m4b", title: "Dune Messiah", author: "Frank Herbert"))

    let shared = BookFingerprint(from: book("theirs/dune.m4b", title: "Dune", author: "Frank Herbert"))

    XCTAssertEqual(matcher.find(matching: shared)?.relativePath, "mine/Dune.m4b")
    XCTAssertEqual(libraryService.searchAllBooksQueryLimitOffsetReceivedArguments?.query, "dune")
  }

  func testTheMatcherRefusesAnotherEditionOrLayout() {
    let matcher = BookLibraryMatcher(libraryService: libraryService, playbackService: playbackService)
    let shared = BookFingerprint(from: book("Dune.m4b", title: "Dune", author: "Frank Herbert"))

    add(book("author.m4b", title: "Dune", author: "Someone Else"))
    add(book("abridged.m4b", title: "Dune", author: "Frank Herbert", chapterDuration: 40))
    add(book("split", title: "Dune", author: "Frank Herbert", files: ["split/1.mp3", "split/2.mp3"]))
    XCTAssertNil(matcher.find(matching: shared))

    /// Encoders round a book's length differently: a few seconds apart is the same book
    add(book("close.m4b", title: "Dune", author: "Frank Herbert", chapterDuration: 52))
    XCTAssertEqual(matcher.find(matching: shared)?.relativePath, "close.m4b")
  }

  func testTheMatcherPrefersTheCopyWithTheSameChapters() {
    let matcher = BookLibraryMatcher(libraryService: libraryService, playbackService: playbackService)
    add(book("a-unchaptered.m4b", title: "Dune", files: ["a-unchaptered.m4b"], chapterDuration: 100))
    add(book("b-chaptered.m4b", title: "Dune"))

    let shared = BookFingerprint(from: book("Dune.m4b", title: "Dune"))

    XCTAssertEqual(matcher.find(matching: shared)?.relativePath, "b-chaptered.m4b")
  }

  // MARK: - Joining

  func testTheBookAlreadyLoadedJoinsAsItIs() async {
    let dune = add(book("Dune.m4b", title: "Dune"))
    playerManager.load(dune, intent: .idle)
    await waitUntil("its item is in the player") { self.items.count == 1 }
    items[0].become(.readyToPlay)
    await settle()

    let results = await join(dune)

    XCTAssertEqual(results, [.success("Dune.m4b")])
    XCTAssertEqual(items.count, 1, "nothing was loaded again")
  }

  func testTheLoadedBookWhoseFileFailedIsLoadedAgainBeforeItJoins() async {
    let dune = add(book("Dune.m4b", title: "Dune", currentTime: 30))
    let unreadable = NSError(domain: AVFoundationErrorDomain, code: AVError.fileFormatNotRecognized.rawValue)
    playerManager.load(dune, intent: .idle)
    await waitUntil("its item is in the player") { self.items.count == 1 }
    items[0].become(.failed, error: unreadable)
    await settle()
    var results: [Result<String, SharePlayJoinFailure>] = []

    sut.loadLocalCopy(of: BookFingerprint(from: dune)) { results.append($0) }
    await waitUntil("the book is loaded again") { self.items.count == 2 }
    await settle()
    XCTAssertEqual(results, [], "a book that can't play must not join: its next play would seek with the session attached")

    items[1].become(.failed, error: unreadable)
    await waitUntil("the join completes") { !results.isEmpty }

    XCTAssertEqual(results, [.failure(.loadFailed)])
    XCTAssertTrue(player.playCalls.isEmpty)
  }

  func testTheLoadedBookStillLoadingJoinsOnceItCanPlay() async {
    let dune = add(book("Dune.m4b", title: "Dune"))
    playerManager.load(dune, intent: .idle)
    await waitUntil("its item is in the player") { self.items.count == 1 }
    var results: [Result<String, SharePlayJoinFailure>] = []

    sut.loadLocalCopy(of: BookFingerprint(from: dune)) { results.append($0) }
    await settle()
    XCTAssertEqual(results, [])

    items[0].become(.readyToPlay)
    await waitUntil("the join completes") { !results.isEmpty }

    XCTAssertEqual(results, [.success("Dune.m4b")])
    XCTAssertEqual(items.count, 1, "nothing was loaded again")
  }

  func testAMatchIsLoadedSilentlyAndJoinsOnceItCanPlay() async {
    let dune = add(book("Dune.m4b", title: "Dune", currentTime: 30))
    var results: [Result<String, SharePlayJoinFailure>] = []

    sut.loadLocalCopy(of: BookFingerprint(from: dune)) { results.append($0) }
    await waitUntil("its item is in the player") { self.items.count == 1 }
    await settle()
    XCTAssertEqual(results, [], "the session must not reach the player before the saved position does")

    items[0].become(.readyToPlay)
    await waitUntil("the join completes") { !results.isEmpty }

    XCTAssertEqual(results, [.success("Dune.m4b")])
    XCTAssertEqual(player.seekTargets, [30])
    XCTAssertTrue(player.playCalls.isEmpty)
  }

  func testABookThatIsNotInTheLibraryFailsAtOnce() {
    var results: [Result<String, SharePlayJoinFailure>] = []

    sut.loadLocalCopy(of: BookFingerprint(from: book("Dune.m4b", title: "Dune"))) { results.append($0) }

    XCTAssertEqual(results, [.failure(.bookNotFound)])
    XCTAssertNil(playerManager.currentItem)
  }

  func testAMatchThatCannotBeLoadedFails() async {
    let dune = add(book("Dune.m4b", title: "Dune"))
    var results: [Result<String, SharePlayJoinFailure>] = []

    sut.loadLocalCopy(of: BookFingerprint(from: dune)) { results.append($0) }
    await waitUntil("its item is in the player") { self.items.count == 1 }
    items[0].become(.failed, error: NSError(domain: AVFoundationErrorDomain, code: AVError.fileFormatNotRecognized.rawValue))
    await waitUntil("the join completes") { !results.isEmpty }

    XCTAssertEqual(results, [.failure(.loadFailed)])
  }

  func testOnlyTheLatestOfOverlappingJoinsCompletes() async {
    let dune = add(book("Dune.m4b", title: "Dune"))
    let emma = add(book("Emma.m4b", title: "Emma"))
    var results: [String: [Result<String, SharePlayJoinFailure>]] = [:]

    sut.loadLocalCopy(of: BookFingerprint(from: dune)) { results["Dune", default: []].append($0) }
    await waitUntil("the first book's item is in the player") { self.items.count == 1 }
    sut.loadLocalCopy(of: BookFingerprint(from: emma)) { results["Emma", default: []].append($0) }
    await waitUntil("the second book's item is in the player") { self.items.count == 2 }
    items[1].become(.readyToPlay)
    await waitUntil("the latest join completes") { results["Emma"] != nil }
    await settle()

    XCTAssertEqual(results, ["Emma": [.success("Emma.m4b")]], "the superseded join must neither join nor leave")
    XCTAssertEqual(playerManager.currentItem?.relativePath, "Emma.m4b")
  }

  func testAJoinDroppedWithItsSessionNeverCompletes() async {
    let dune = add(book("Dune.m4b", title: "Dune"))
    var results: [Result<String, SharePlayJoinFailure>] = []

    sut.loadLocalCopy(of: BookFingerprint(from: dune)) { results.append($0) }
    await waitUntil("its item is in the player") { self.items.count == 1 }
    sut.leaveSession()
    items[0].become(.readyToPlay)
    await settle()

    XCTAssertEqual(results, [])
  }

  // MARK: - The coordinated book

  func testReloadingTheCoordinatedBookKeepsTheSession() async {
    let dune = add(book("Dune.m4b", title: "Dune"))
    await loadUntilReady(dune)
    sut.coordinate("Dune.m4b", as: "shared-book") { _ in }
    XCTAssertNotNil(player.playbackCoordinator.delegate)

    /// As a play does after a failed load or a media-services reset: nil is published on the way
    playerManager.load(dune, intent: .idle)
    await waitUntil("the book is loaded again") { self.items.count == 2 }
    await settle()

    XCTAssertNotNil(player.playbackCoordinator.delegate, "the same book came back: nothing to leave")
  }

  func testAnotherBookOrNoneLeavesTheSession() async {
    let dune = add(book("Dune.m4b", title: "Dune"))
    await loadUntilReady(dune)
    sut.coordinate("Dune.m4b", as: "shared-book") { _ in }

    playerManager.load(book("Emma.m4b", title: "Emma"), intent: .idle)
    await settle()
    XCTAssertNil(player.playbackCoordinator.delegate, "other content must not stay coordinated")

    playerManager.load(dune, intent: .idle)
    await settle()
    sut.coordinate("Dune.m4b", as: "shared-book") { _ in }
    playerManager.stop()
    await settle()
    XCTAssertNil(player.playbackCoordinator.delegate)
  }

  func testANewJoinStartsFromAnUncoordinatedPlayer() async {
    let dune = add(book("Dune.m4b", title: "Dune"))
    let emma = add(book("Emma.m4b", title: "Emma", currentTime: 30))
    await loadUntilReady(dune)
    sut.coordinate("Dune.m4b", as: "shared-book") { _ in }
    var results: [Result<String, SharePlayJoinFailure>] = []

    sut.loadLocalCopy(of: BookFingerprint(from: emma)) { results.append($0) }

    XCTAssertNil(player.playbackCoordinator.delegate, "the next book's saved position must not go to the old group")
    await waitUntil("the next book's item is in the player") { self.items.count == 2 }
    items[1].become(.readyToPlay)
    await waitUntil("the join completes") { !results.isEmpty }
    XCTAssertEqual(results, [.success("Emma.m4b")], "and loading it is no reason to leave")
  }

  // MARK: - Books

  /// A book of 50 s chapters, one per entry of `files`: by default two chapters in one file named after its path
  private func book(
    _ relativePath: String,
    title: String,
    author: String = "author",
    files: [String]? = nil,
    chapterDuration: TimeInterval = 50,
    currentTime: TimeInterval = 0
  ) -> PlayableItem {
    let files = files ?? [relativePath, relativePath]
    let chapters = files.enumerated().map { index, file in
      PlayableChapter(
        title: "chapter \(index + 1)",
        author: author,
        start: Double(index) * chapterDuration,
        duration: chapterDuration,
        relativePath: file,
        remoteURL: nil,
        externalURL: nil,
        index: Int16(index + 1)
      )
    }

    return PlayableItem(
      title: title,
      author: author,
      chapters: chapters,
      currentTime: currentTime,
      duration: Double(files.count) * chapterDuration,
      relativePath: relativePath,
      uuid: relativePath,
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: Set(files).count > 1
    )
  }

  @discardableResult
  private func add(_ book: PlayableItem) -> PlayableItem {
    library[book.relativePath] = book
    return book
  }

  private func libraryItem(for book: PlayableItem) -> SimpleLibraryItem {
    SimpleLibraryItem(
      title: book.title,
      details: book.author,
      speed: 1,
      currentTime: book.currentTime,
      duration: book.duration,
      percentCompleted: 0,
      isFinished: false,
      relativePath: book.relativePath,
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: book.relativePath,
      lastPlayDate: nil,
      type: book.isBoundBook ? .bound : .book,
      uuid: book.uuid
    )
  }

  // MARK: - Driving the join

  /// Loads `book` silently and makes its item ready
  private func loadUntilReady(_ book: PlayableItem) async {
    let count = items.count
    playerManager.load(book, intent: .idle)
    await waitUntil("its item is in the player") { self.items.count == count + 1 }
    items[count].become(.readyToPlay)
    await settle()
  }

  /// Joins `book`, which needs nothing loaded, and returns what its completion got
  private func join(_ book: PlayableItem) async -> [Result<String, SharePlayJoinFailure>] {
    var results: [Result<String, SharePlayJoinFailure>] = []
    sut.loadLocalCopy(of: BookFingerprint(from: book)) { results.append($0) }
    await waitUntil("the join completes") { !results.isEmpty }
    await settle()
    return results
  }

  private func waitUntil(
    _ what: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: () -> Bool
  ) async {
    let deadline = Date().addingTimeInterval(2)
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
