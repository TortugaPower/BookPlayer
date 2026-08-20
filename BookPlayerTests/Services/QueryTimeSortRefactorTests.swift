//
//  QueryTimeSortRefactorTests.swift
//  BookPlayerTests
//
//  The query-time-sort refactor's own suite: asserts the NEW contract that
//  SortCharacterizationTests deliberately couldn't — `orderRank` is owned by
//  the custom arrangement (sync + manual reorders) and automatic sorts never
//  touch it; order is derived from the sticky pref at fetch time.
//
//  The headline test is the scramble regression: a sync pull overwriting the
//  rank column must not reorder an automatically-sorted list.
//

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import CoreData
import XCTest

@MainActor
final class QueryTimeSortRefactorTests: XCTestCase {
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

  // MARK: - The bug this refactor exists to fix

  /// Pro-user scramble regression: with an automatic sort selected, a sync pull
  /// that overwrites the rank column with stale server ranks must not change
  /// the rendered order. The rank write itself is EXPECTED (server ranks are
  /// the synced custom arrangement) — the screen just no longer reads them.
  func testSyncPullDoesNotReorderAutoSortedList() async throws {
    harness.seedBook(relativePath: "cherry.txt", rank: 0)
    harness.seedBook(relativePath: "apple.txt", rank: 1)
    harness.seedBook(relativePath: "banana.txt", rank: 2)
    harness.save()
    libraryService.sortContents(at: nil, by: .metadataTitle)
    XCTAssertEqual(harness.renderedOrder(), ["apple.txt", "banana.txt", "cherry.txt"])

    // Adversarial server ranks: would render banana, cherry, apple if obeyed.
    let serverItems = try SyncResponseFixtures.makeItemsDictionary([
      SyncResponseFixtures.itemJSON(relativePath: "cherry.txt", orderRank: 1),
      SyncResponseFixtures.itemJSON(relativePath: "apple.txt", orderRank: 2),
      SyncResponseFixtures.itemJSON(relativePath: "banana.txt", orderRank: 0),
    ])
    await libraryService.updateInfo(for: serverItems, parentFolder: nil)

    XCTAssertEqual(
      harness.renderedOrder(),
      ["apple.txt", "banana.txt", "cherry.txt"],
      "a pull must never scramble an automatically-sorted list"
    )
    let ranks = harness.rankColumn()
    XCTAssertEqual(ranks["banana.txt"], 0, "server ranks still land in the column")
    XCTAssertEqual(ranks["cherry.txt"], 1)
    XCTAssertEqual(ranks["apple.txt"], 2)
  }

  // MARK: - Automatic sorts never write ranks

  func testPickingSortPersistsPrefWithoutTouchingRanks() {
    harness.seedBook(relativePath: "cherry.txt", rank: 0)
    harness.seedBook(relativePath: "apple.txt", rank: 1)
    harness.save()

    libraryService.sortContents(at: nil, by: .metadataTitle)

    XCTAssertEqual(harness.renderedOrder(), ["apple.txt", "cherry.txt"])
    XCTAssertEqual(preferences.effectiveSort(forLocation: .libraryRoot), .automatic(.metadataTitle))
    let ranks = harness.rankColumn()
    XCTAssertEqual(ranks["cherry.txt"], 0, "the latent custom arrangement survives underneath")
    XCTAssertEqual(ranks["apple.txt"], 1)
  }

  func testSyncInsertLandsSortedWithoutRankRewrite() async throws {
    harness.seedBook(relativePath: "bbb.txt", rank: 0)
    harness.seedBook(relativePath: "ddd.txt", rank: 1)
    harness.save()
    preferences.setSort(.automatic(.metadataTitle), forLocation: .libraryRoot)

    let newItems = try SyncResponseFixtures.makeItemsDictionary([
      SyncResponseFixtures.itemJSON(relativePath: "aaa.txt", orderRank: 99)
    ])
    await libraryService.storeNewItems(from: newItems, parentFolder: nil)

    XCTAssertEqual(harness.renderedOrder(), ["aaa.txt", "bbb.txt", "ddd.txt"])
    let ranks = harness.rankColumn()
    XCTAssertEqual(ranks["bbb.txt"], 0, "existing ranks are untouched — no re-sort hook ran")
    XCTAssertEqual(ranks["ddd.txt"], 1)
    XCTAssertEqual(ranks["aaa.txt"], 99, "the insert keeps its server rank")
  }

  // MARK: - Custom transition freezes the visible order

  func testAdoptCurrentOrderAsCustomFreezesVisibleOrder() {
    harness.seedBook(relativePath: "cherry.txt", rank: 0)
    harness.seedBook(relativePath: "apple.txt", rank: 1)
    harness.seedBook(relativePath: "banana.txt", rank: 2)
    harness.save()
    libraryService.sortContents(at: nil, by: .metadataTitle)

    libraryService.adoptCurrentOrderAsCustom(at: nil)

    XCTAssertEqual(preferences.effectiveSort(forLocation: .libraryRoot), .custom)
    XCTAssertEqual(
      harness.renderedOrder(),
      ["apple.txt", "banana.txt", "cherry.txt"],
      "WYSIWYG: the transition freezes exactly what was on screen"
    )
    let ranks = harness.rankColumn()
    XCTAssertEqual(ranks["apple.txt"], 0)
    XCTAssertEqual(ranks["banana.txt"], 1)
    XCTAssertEqual(ranks["cherry.txt"], 2)
  }

  func testAdoptCurrentOrderAsCustomIsIdempotent() {
    harness.seedBook(relativePath: "b.txt", rank: 0)
    harness.seedBook(relativePath: "a.txt", rank: 1)
    harness.save()

    libraryService.adoptCurrentOrderAsCustom(at: nil)
    let firstFreeze = harness.rankColumn()
    libraryService.adoptCurrentOrderAsCustom(at: nil)

    XCTAssertEqual(harness.rankColumn(), firstFreeze)
    XCTAssertEqual(harness.renderedOrder(), ["b.txt", "a.txt"])
  }

  // MARK: - Drag operates on the visible order (capture-before-flip)

  func testDragUnderAutomaticSortMovesVisibleRows() {
    // Ranks deliberately disagree with the title order the user is looking at.
    harness.seedBook(relativePath: "cherry.txt", rank: 0)
    harness.seedBook(relativePath: "apple.txt", rank: 1)
    harness.seedBook(relativePath: "banana.txt", rank: 2)
    harness.save()
    preferences.setSort(.automatic(.metadataTitle), forLocation: .libraryRoot)
    // Visible: apple, banana, cherry. Drag the top row below the last row.
    libraryService.reorderItems(inside: nil, fromOffsets: IndexSet(integer: 0), toOffset: 3)

    XCTAssertEqual(preferences.effectiveSort(forLocation: .libraryRoot), .custom)
    XCTAssertEqual(
      harness.renderedOrder(),
      ["banana.txt", "cherry.txt", "apple.txt"],
      "the drag applies to what the user saw, not to the hidden rank order"
    )
  }

  // MARK: - "Most recent" is live (the staleness fix)

  func testMostRecentReflectsPlaybackImmediately() {
    let now = Date()
    harness.seedBook(relativePath: "a.txt", rank: 0, lastPlayDate: now.addingTimeInterval(-200))
    let bookB = harness.seedBook(relativePath: "b.txt", rank: 1, lastPlayDate: now.addingTimeInterval(-100))
    harness.seedBook(relativePath: "c.txt", rank: 2, lastPlayDate: nil)
    harness.save()
    preferences.setSort(.automatic(.mostRecent), forLocation: .libraryRoot)
    XCTAssertEqual(harness.renderedOrder(), ["b.txt", "a.txt", "c.txt"])

    bookB.lastPlayDate = now.addingTimeInterval(-300)
    harness.seedBook(relativePath: "d.txt", rank: 3, lastPlayDate: now)
    harness.save()

    XCTAssertEqual(
      harness.renderedOrder(),
      ["d.txt", "a.txt", "b.txt", "c.txt"],
      "the order keys on live lastPlayDate — no hook needed to refresh it"
    )
  }

  // MARK: - Playback navigation follows the visible order

  func testPrevNextFollowVisibleOrderUnderTitleSort() {
    harness.seedBook(relativePath: "cherry.txt", rank: 0)
    harness.seedBook(relativePath: "apple.txt", rank: 1)
    harness.seedBook(relativePath: "banana.txt", rank: 2)
    harness.save()
    preferences.setSort(.automatic(.metadataTitle), forLocation: .libraryRoot)
    let playbackService = PlaybackService()
    playbackService.setup(libraryService: libraryService)

    let next = playbackService.getPlayableItem(
      after: "apple.txt", parentFolder: nil, autoplayed: false, restartFinished: false
    )
    XCTAssertEqual(next?.relativePath, "banana.txt", "next matches the list, not the rank column")

    let previous = playbackService.getPlayableItem(before: "cherry.txt", parentFolder: nil)
    XCTAssertEqual(previous?.relativePath, "banana.txt")

    let afterLast = playbackService.getPlayableItem(
      after: "cherry.txt", parentFolder: nil, autoplayed: false, restartFinished: false
    )
    XCTAssertNil(afterLast)
  }

  /// A repeat freeze must not just leave ranks unchanged — it must emit ZERO
  /// sync updates. This is the contract the `orderRank != index` filter in
  /// `freezeVisibleOrder` provides; without this test that clause could be
  /// deleted as "redundant" without anything failing.
  func testRepeatAdoptEmitsNoSyncUpdates() {
    harness.seedBook(relativePath: "b.txt", rank: 5)
    harness.seedBook(relativePath: "a.txt", rank: 9)
    harness.save()

    libraryService.adoptCurrentOrderAsCustom(at: nil)

    var emissions: [[String: Any]] = []
    let subscription = libraryService.immediateProgressUpdatePublisher.sink { emissions.append($0) }
    libraryService.adoptCurrentOrderAsCustom(at: nil)
    subscription.cancel()

    XCTAssertTrue(emissions.isEmpty, "a repeat freeze must not schedule sync work")
  }

  /// The pref flip deliberately precedes the empty-contents guard (matching
  /// `reverseContents`' pinned behavior): an empty folder still becomes Custom.
  func testAdoptOnEmptyFolderStillFlipsPref() {
    let folder = harness.seedFolder(relativePath: "empty", rank: 0)
    harness.save()
    preferences.setSort(.automatic(.metadataTitle), forLocation: .folder(
      LibraryItemRef(relativePath: "empty", uuid: folder.uuid)
    ))

    libraryService.adoptCurrentOrderAsCustom(at: "empty")

    XCTAssertEqual(
      preferences.effectiveSort(forLocation: .folder(LibraryItemRef(relativePath: "empty", uuid: folder.uuid))),
      .custom
    )
  }

  // MARK: - Sign-out must not re-scramble the library

  /// Logout wipes every `library_sort:*` key; the visible order must survive
  /// via the freeze-before-wipe in `PreferencesSyncService.handleLogout`.
  func testLogoutPreservesVisibleOrder() {
    harness.seedBook(relativePath: "cherry.txt", rank: 0)
    harness.seedBook(relativePath: "apple.txt", rank: 1)
    harness.seedBook(relativePath: "banana.txt", rank: 2)
    harness.save()
    libraryService.sortContents(at: nil, by: .metadataTitle)
    XCTAssertEqual(harness.renderedOrder(), ["apple.txt", "banana.txt", "cherry.txt"])

    preferences.handleLogout()

    XCTAssertFalse(harness.hasAnySortPreferencePersisted, "logout still wipes the pref keys")
    XCTAssertEqual(
      harness.renderedOrder(),
      ["apple.txt", "banana.txt", "cherry.txt"],
      "the order the user saw survives sign-out, frozen into ranks"
    )
    XCTAssertEqual(preferences.effectiveSort(forLocation: .libraryRoot), .custom)
  }

  // MARK: - Navigation edge: current item unknown

  /// If the playing item was deleted/moved mid-playback, "next" must stop —
  /// never hop out of the stale folder (symmetric with "previous").
  func testNextReturnsNilWhenCurrentItemMissingFromSiblings() {
    harness.seedBook(relativePath: "a.txt", rank: 0)
    harness.seedBook(relativePath: "b.txt", rank: 1)
    harness.save()
    let playbackService = PlaybackService()
    playbackService.setup(libraryService: libraryService)

    let next = playbackService.getPlayableItem(
      after: "ghost.txt", parentFolder: nil, autoplayed: false, restartFinished: false
    )
    XCTAssertNil(next)

    let previous = playbackService.getPlayableItem(before: "ghost.txt", parentFolder: nil)
    XCTAssertNil(previous)
  }

  // MARK: - watchOS fallback (no preferences service wired)

  func testNilPreferencesServiceFallsBackToRankOrder() {
    harness.seedBook(relativePath: "cherry.txt", rank: 0)
    harness.seedBook(relativePath: "apple.txt", rank: 1)
    harness.save()
    preferences.setSort(.automatic(.metadataTitle), forLocation: .libraryRoot)
    XCTAssertEqual(harness.renderedOrder(), ["apple.txt", "cherry.txt"])

    libraryService.preferencesService = nil

    XCTAssertEqual(
      harness.renderedOrder(),
      ["cherry.txt", "apple.txt"],
      "without a preferences service (watchOS) the fetch is rank-ordered"
    )
  }
}
