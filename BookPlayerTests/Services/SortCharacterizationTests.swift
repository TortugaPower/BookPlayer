//
//  SortCharacterizationTests.swift
//  BookPlayerTests
//
//  Phase 0 of the query-time-sort refactor: pins the OBSERVABLE behavior that
//  must survive the refactor byte-for-byte. Every assertion here is written
//  against user-visible outcomes (rendered order, persisted prefs, playback
//  navigation) — never against the materialization mechanism (rank rewrites)
//  that the refactor deletes. If a test in this file breaks during the
//  refactor, user-facing behavior regressed.
//
//  Uses SortIntegrationHarness: a real PreferencesSyncService (real SortLocation
//  gates and key routing) wired to a real LibraryService over a real SQLite
//  store, so the sync paths' background-context writes are production-faithful.
//

@testable import BookPlayer
@testable import BookPlayerKit
import CoreData
import XCTest

/// @MainActor because the sync-path tests write on the background context and
/// then assert via view-context fetches; async XCTest methods otherwise run off
/// the main thread, racing the background→view merge (CI crashed with
/// "Collection was mutated while being enumerated" inside a view-context fetch).
/// Production accesses the view context from the main actor — tests must too.
@MainActor
final class SortCharacterizationTests: XCTestCase {
  private var harness: SortIntegrationHarness!
  private var libraryService: LibraryService { harness.libraryService }
  private var preferences: PreferencesSyncService { harness.preferences }

  override func setUp() {
    super.setUp()
    harness = SortIntegrationHarness()
  }

  override func tearDown() {
    harness.tearDown()
    harness = nil
    super.tearDown()
  }

  // MARK: - Picking a sort

  func testPickingTitleSortPersistsPrefAndRendersSorted() {
    harness.seedBook(relativePath: "cherry.txt", rank: 0)
    harness.seedBook(relativePath: "apple.txt", rank: 1)
    harness.seedBook(relativePath: "banana.txt", rank: 2)
    harness.save()

    libraryService.sortContents(at: nil, by: .metadataTitle)

    XCTAssertEqual(harness.renderedOrder(), ["apple.txt", "banana.txt", "cherry.txt"])
    XCTAssertEqual(preferences.effectiveSort(forLocation: .libraryRoot), .automatic(.metadataTitle))
  }

  func testReverseUnderTitleSortReversesVisibleOrderAndTransitionsToCustom() {
    harness.seedBook(relativePath: "cherry.txt", rank: 0)
    harness.seedBook(relativePath: "apple.txt", rank: 1)
    harness.seedBook(relativePath: "banana.txt", rank: 2)
    harness.save()
    libraryService.sortContents(at: nil, by: .metadataTitle)

    libraryService.reverseContents(at: nil)

    XCTAssertEqual(harness.renderedOrder(), ["cherry.txt", "banana.txt", "apple.txt"])
    XCTAssertEqual(preferences.effectiveSort(forLocation: .libraryRoot), .custom)
  }

  // MARK: - Import (today: Hook 2 re-sorts; after: the query sorts)

  func testImportUnderTitleSortRendersSorted() async {
    preferences.setSort(.automatic(.metadataTitle), forLocation: .libraryRoot)
    let processedFolder = DataManager.getProcessedFolderURL()
    let contents = "bookcontents".data(using: .utf8)!
    let gamma = DataTestUtils.generateTestFile(name: "gamma.txt", contents: contents, destinationFolder: processedFolder)
    let alpha = DataTestUtils.generateTestFile(name: "alpha.txt", contents: contents, destinationFolder: processedFolder)
    let beta = DataTestUtils.generateTestFile(name: "beta.txt", contents: contents, destinationFolder: processedFolder)

    _ = await libraryService.insertItems(from: [gamma, alpha, beta])

    XCTAssertEqual(harness.renderedOrder(), ["alpha.txt", "beta.txt", "gamma.txt"])
  }

  func testImportUnderCustomAppendsInInsertionOrder() async {
    let processedFolder = DataManager.getProcessedFolderURL()
    let contents = "bookcontents".data(using: .utf8)!
    let gamma = DataTestUtils.generateTestFile(name: "gamma.txt", contents: contents, destinationFolder: processedFolder)
    let alpha = DataTestUtils.generateTestFile(name: "alpha.txt", contents: contents, destinationFolder: processedFolder)

    _ = await libraryService.insertItems(from: [gamma, alpha])

    XCTAssertEqual(harness.renderedOrder(), ["gamma.txt", "alpha.txt"])
  }

  // MARK: - Move (source compaction survives the refactor; it's rank hygiene, not sort)

  /// Compaction runs only when the SOURCE is a folder (`rebuildOrderRank(in:)`
  /// is gated on a non-nil original parent path in `moveItems`).
  func testMoveOutOfFolderCompactsSourceRanksAndPreservesOrder() throws {
    let processedFolder = DataManager.getProcessedFolderURL()
    let contents = "bookcontents".data(using: .utf8)!
    let srcDir = try DataTestUtils.generateTestFolder(name: "src", destinationFolder: processedFolder)
    for name in ["a.txt", "b.txt", "c.txt"] {
      DataTestUtils.generateTestFile(name: name, contents: contents, destinationFolder: srcDir)
    }
    let src = try StubFactory.folder(dataManager: harness.dataManager, title: "src")
    src.orderRank = 0
    libraryService.getLibraryReference().addToItems(src)
    harness.seedBook(relativePath: "src/a.txt", rank: 0, into: src)
    let bookB = harness.seedBook(relativePath: "src/b.txt", rank: 1, into: src)
    harness.seedBook(relativePath: "src/c.txt", rank: 2, into: src)
    harness.save()

    try libraryService.moveItems(
      [LibraryItemRef(relativePath: "src/b.txt", uuid: bookB.uuid)],
      inside: nil
    )

    XCTAssertEqual(harness.renderedOrder(at: "src"), ["src/a.txt", "src/c.txt"])
    let srcRanks = harness.rankColumn(at: "src")
    XCTAssertEqual(srcRanks["src/a.txt"], 0)
    XCTAssertEqual(srcRanks["src/c.txt"], 1, "the source folder is compacted after a move-out")
    XCTAssertEqual(harness.renderedOrder(), ["src", "b.txt"], "the moved item is appended at the destination")
  }

  /// A root-level source is NOT compacted today (the compaction call is gated on
  /// a folder parent). Sparse ranks are harmless — ordering needs no contiguity —
  /// and the refactor keeps this behavior as-is.
  func testMoveOutOfRootLeavesSparseRanksAndPreservesOrder() throws {
    let processedFolder = DataManager.getProcessedFolderURL()
    let contents = "bookcontents".data(using: .utf8)!
    for name in ["a.txt", "b.txt", "c.txt", "d.txt"] {
      DataTestUtils.generateTestFile(name: name, contents: contents, destinationFolder: processedFolder)
    }
    harness.seedBook(relativePath: "a.txt", rank: 0)
    let bookB = harness.seedBook(relativePath: "b.txt", rank: 1)
    harness.seedBook(relativePath: "c.txt", rank: 2)
    harness.seedBook(relativePath: "d.txt", rank: 3)
    harness.save()
    _ = try libraryService.createFolder(with: "dest", inside: nil)

    try libraryService.moveItems(
      [LibraryItemRef(relativePath: "b.txt", uuid: bookB.uuid)],
      inside: "dest"
    )

    XCTAssertEqual(harness.renderedOrder(), ["a.txt", "c.txt", "d.txt", "dest"])
    let ranks = harness.rankColumn()
    XCTAssertEqual(ranks["a.txt"], 0)
    XCTAssertEqual(ranks["c.txt"], 2)
    XCTAssertEqual(ranks["d.txt"], 3)
    XCTAssertEqual(ranks["dest"], 4)
    XCTAssertEqual(harness.renderedOrder(at: "dest"), ["dest/b.txt"])
  }

  // MARK: - Sync pull (today: Hook 4 re-sorts inserts; after: the query sorts)

  func testSyncInsertUnderTitleSortRendersSorted() async throws {
    harness.seedBook(relativePath: "bbb.txt", rank: 0)
    harness.seedBook(relativePath: "ddd.txt", rank: 1)
    harness.save()
    preferences.setSort(.automatic(.metadataTitle), forLocation: .libraryRoot)

    let newItems = try SyncResponseFixtures.makeItemsDictionary([
      SyncResponseFixtures.itemJSON(relativePath: "aaa.txt", orderRank: 99),
      SyncResponseFixtures.itemJSON(relativePath: "ccc.txt", orderRank: 98),
    ])
    await libraryService.storeNewItems(from: newItems, parentFolder: nil)

    XCTAssertEqual(harness.renderedOrder(), ["aaa.txt", "bbb.txt", "ccc.txt", "ddd.txt"])
  }

  func testSyncInsertUnderCustomFollowsServerRanks() async throws {
    harness.seedBook(relativePath: "first.txt", rank: 0)
    harness.save()

    let newItems = try SyncResponseFixtures.makeItemsDictionary([
      SyncResponseFixtures.itemJSON(relativePath: "server-second.txt", orderRank: 1),
      SyncResponseFixtures.itemJSON(relativePath: "server-third.txt", orderRank: 2),
    ])
    await libraryService.storeNewItems(from: newItems, parentFolder: nil)

    XCTAssertEqual(
      harness.renderedOrder(),
      ["first.txt", "server-second.txt", "server-third.txt"]
    )
  }

  /// The refactor KEEPS this write unguarded on purpose: server ranks are the
  /// synced custom arrangement and must always land in the column. (What changes
  /// in the refactor is that the rendered order stops reading the column while
  /// an automatic sort is active — that assertion arrives with the refactor.)
  func testSyncUpdateWritesServerRanksToColumn() async throws {
    harness.seedBook(relativePath: "x.txt", rank: 0)
    harness.seedBook(relativePath: "y.txt", rank: 1)
    harness.seedBook(relativePath: "z.txt", rank: 2)
    harness.save()

    let serverItems = try SyncResponseFixtures.makeItemsDictionary([
      SyncResponseFixtures.itemJSON(relativePath: "x.txt", orderRank: 2),
      SyncResponseFixtures.itemJSON(relativePath: "y.txt", orderRank: 1),
      SyncResponseFixtures.itemJSON(relativePath: "z.txt", orderRank: 0),
    ])
    await libraryService.updateInfo(for: serverItems, parentFolder: nil)

    let ranks = harness.rankColumn()
    XCTAssertEqual(ranks["x.txt"], 2)
    XCTAssertEqual(ranks["y.txt"], 1)
    XCTAssertEqual(ranks["z.txt"], 0)
  }

  // MARK: - Playback navigation (D7 replaces the mechanism; these outcomes stay)

  func testPrevNextUnderCustomFollowsRankOrder() {
    harness.seedBook(relativePath: "a.txt", rank: 0)
    harness.seedBook(relativePath: "b.txt", rank: 1)
    harness.seedBook(relativePath: "c.txt", rank: 2)
    harness.save()
    let playbackService = PlaybackService()
    playbackService.setup(libraryService: libraryService)

    let next = playbackService.getPlayableItem(
      after: "a.txt", parentFolder: nil, autoplayed: false, restartFinished: false
    )
    XCTAssertEqual(next?.relativePath, "b.txt")

    let previous = playbackService.getPlayableItem(before: "b.txt", parentFolder: nil)
    XCTAssertEqual(previous?.relativePath, "a.txt")

    let afterLast = playbackService.getPlayableItem(
      after: "c.txt", parentFolder: nil, autoplayed: false, restartFinished: false
    )
    XCTAssertNil(afterLast)
  }

  func testAutoplaySkipsFinishedItems() {
    harness.seedBook(relativePath: "a.txt", rank: 0)
    harness.seedBook(relativePath: "b.txt", rank: 1, isFinished: true)
    harness.seedBook(relativePath: "c.txt", rank: 2)
    harness.save()
    let playbackService = PlaybackService()
    playbackService.setup(libraryService: libraryService)

    let next = playbackService.getPlayableItem(
      after: "a.txt", parentFolder: nil, autoplayed: true, restartFinished: false
    )
    XCTAssertEqual(next?.relativePath, "c.txt")
  }

  func testFolderTapPicksFirstUnfinishedInRankOrder() throws {
    let folder = harness.seedFolder(relativePath: "novels", rank: 0)
    harness.seedBook(relativePath: "novels/one.txt", rank: 0, into: folder, isFinished: true)
    harness.seedBook(relativePath: "novels/two.txt", rank: 1, into: folder)
    harness.seedBook(relativePath: "novels/three.txt", rank: 2, into: folder)
    harness.save()
    let playbackService = PlaybackService()
    playbackService.setup(libraryService: libraryService)

    let folderItem = try XCTUnwrap(libraryService.getSimpleItem(with: "novels"))
    let first = try playbackService.getFirstPlayableItem(in: folderItem, isUnfinished: true)

    XCTAssertEqual(first?.relativePath, "novels/two.txt")
  }

  // MARK: - Bound books: the rank order IS the playback timeline, sort-proof

  func testBoundBookTimelineFollowsRankOrderRegardlessOfRootSort() throws {
    let bound = harness.seedFolder(relativePath: "bnd", rank: 0, type: .bound)
    // Ranks deliberately disagree with any title/filename order.
    harness.seedBook(relativePath: "bnd/03 part.mp3", rank: 0, into: bound)
    harness.seedBook(relativePath: "bnd/01 part.mp3", rank: 1, into: bound)
    harness.seedBook(relativePath: "bnd/02 part.mp3", rank: 2, into: bound)
    harness.save()
    preferences.setSort(.automatic(.metadataTitle), forLocation: .libraryRoot)
    let playbackService = PlaybackService()
    playbackService.setup(libraryService: libraryService)

    let boundItem = try XCTUnwrap(libraryService.getSimpleItem(with: "bnd"))
    let playable = try playbackService.getPlayableItem(from: boundItem)

    XCTAssertEqual(
      playable.chapters.map(\.relativePath),
      ["bnd/03 part.mp3", "bnd/01 part.mp3", "bnd/02 part.mp3"]
    )
  }

  // MARK: - One-shot sort on .unresolved locations (a bulk custom rearrangement)

  func testOneShotSortOnUnresolvedRewritesRanksWithoutPersistingPref() {
    let folder = harness.seedFolder(
      relativePath: "migrating",
      rank: 0,
      uuid: Constants.uuidPlaceholder
    )
    harness.seedBook(relativePath: "migrating/cherry.txt", rank: 0, into: folder)
    harness.seedBook(relativePath: "migrating/apple.txt", rank: 1, into: folder)
    harness.save()

    libraryService.sortContents(at: "migrating", by: .metadataTitle)

    XCTAssertEqual(
      harness.renderedOrder(at: "migrating"),
      ["migrating/apple.txt", "migrating/cherry.txt"]
    )
    XCTAssertFalse(
      harness.hasAnySortPreferencePersisted,
      "an .unresolved location must never persist a sticky-sort preference"
    )
  }

  // MARK: - Per-folder independence (no inheritance from root)

  func testFolderDoesNotInheritRootSort() {
    let folder = harness.seedFolder(relativePath: "series", rank: 0)
    harness.seedBook(relativePath: "series/zeta.txt", rank: 0, into: folder)
    harness.seedBook(relativePath: "series/alpha.txt", rank: 1, into: folder)
    harness.save()

    preferences.setSort(.automatic(.metadataTitle), forLocation: .libraryRoot)

    XCTAssertEqual(
      harness.renderedOrder(at: "series"),
      ["series/zeta.txt", "series/alpha.txt"],
      "a folder keeps its own (custom) order when only the root pref is set"
    )
  }
}
