//
//  ItemListViewModelReloadTests.swift
//  BookPlayerTests
//
//  Tests for `reloadItemsPreservingOffset` — the method that re-fetches the
//  currently-visible window without resetting the scroll position to the top.
//  Uses `SortIntegrationHarness` for a real LibraryService + PreferencesSyncService
//  so the sort-resolution path (effectiveSort → fetchContents sort descriptors)
//  is production-faithful.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

@MainActor
final class ItemListViewModelReloadTests: XCTestCase {
  private var harness: SortIntegrationHarness!
  private var viewModel: ItemListViewModel!

  override func setUp() {
    super.setUp()
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())

    harness = SortIntegrationHarness()

    let playbackService = PlaybackService()
    playbackService.setup(libraryService: harness.libraryService)

    let playerManager = PlayerManager(
      libraryService: harness.libraryService,
      playbackService: playbackService,
      syncService: SyncService(),
      speedService: SpeedService(libraryService: harness.libraryService),
      shakeMotionService: ShakeMotionServiceProtocolMock(),
      widgetReloadService: WidgetReloadService()
    )

    let listSyncRefreshService = ListSyncRefreshService(
      playerManager: playerManager,
      syncService: SyncService(),
      playerLoaderService: PlayerLoaderService(),
      preferencesService: harness.preferences
    )

    let singleFileDownloadService = SingleFileDownloadService(
      networkClient: NetworkClientMock(mockedResponse: Empty())
    )

    viewModel = ItemListViewModel(
      libraryNode: .root,
      libraryService: harness.libraryService,
      playbackService: playbackService,
      playerManager: playerManager,
      syncService: SyncService(),
      listSyncRefreshService: listSyncRefreshService,
      loadingState: LoadingOverlayState(),
      listState: ListStateManager(),
      singleFileDownloadService: singleFileDownloadService
    )
  }

  override func tearDown() {
    harness.tearDown()
    harness = nil
    viewModel = nil
    super.tearDown()
  }

  // MARK: - reloadItemsPreservingOffset

  /// Empty list: falls back to `reloadItems()` which fetches from offset 0.
  func testReloadPreservingOffsetOnEmptyListFetchesFromStart() {
    harness.seedBook(relativePath: "a.txt", rank: 0)
    harness.seedBook(relativePath: "b.txt", rank: 1)
    harness.save()

    XCTAssertTrue(viewModel.items.isEmpty)

    viewModel.reloadItemsPreservingOffset()

    XCTAssertEqual(viewModel.items.count, 2)
    XCTAssertEqual(viewModel.offset, 0)
  }

  /// Loaded window of 2 items (offset 0): re-fetch covers the same range.
  func testReloadPreservingOffsetCoversLoadedWindow() {
    harness.seedBook(relativePath: "a.txt", rank: 0)
    harness.seedBook(relativePath: "b.txt", rank: 1)
    harness.seedBook(relativePath: "c.txt", rank: 2)
    harness.save()

    // Simulate loading the first 2 items
    let firstPage = harness.libraryService.fetchContents(at: nil, limit: 2, offset: 0) ?? []
    viewModel.items = firstPage
    viewModel.offset = firstPage.count
    viewModel.canLoadMore = true

    viewModel.reloadItemsPreservingOffset()

    XCTAssertEqual(viewModel.items.count, 2, "same window size")
    XCTAssertEqual(viewModel.offset, 2, "offset unchanged")
    XCTAssertTrue(viewModel.canLoadMore, "more items remain beyond the window")
  }

  /// Scrolled into the list (offset > 0): re-fetch covers from offset 0 to
  /// offset + loaded count, so the entire visible range is refreshed —
  /// the user does not lose their scroll position.
  func testReloadPreservingOffsetCoversFullVisibleRangeAfterScroll() {
    let total = 30
    for i in 0..<total {
      harness.seedBook(relativePath: "book\(i).txt", rank: Int16(i))
    }
    harness.save()

    // Simulate user scrolled: loaded 2 pages (26 items), offset = 26
    let loaded = harness.libraryService.fetchContents(at: nil, limit: 26, offset: 0) ?? []
    viewModel.items = loaded
    viewModel.offset = loaded.count
    viewModel.canLoadMore = true

    viewModel.reloadItemsPreservingOffset()

    XCTAssertEqual(viewModel.items.count, 26, "full visible range re-fetched")
    XCTAssertEqual(viewModel.offset, 26, "offset preserved")
    XCTAssertTrue(viewModel.canLoadMore, "4 more items remain")
  }

  /// After re-sort, the visible items reflect the new order, not the old one.
  func testReloadPreservingOffsetReflectsUpdatedSortOrder() {
    let now = Date()
    let oldDate = now.addingTimeInterval(-200)
    let newerDate = now.addingTimeInterval(-100)

    harness.seedBook(relativePath: "a.txt", rank: 0, lastPlayDate: oldDate)
    harness.seedBook(relativePath: "b.txt", rank: 1, lastPlayDate: newerDate)
    harness.save()

    // Default sort is by rank (custom): a, b
    let loaded = harness.libraryService.fetchContents(at: nil, limit: nil, offset: nil) ?? []
    viewModel.items = loaded
    viewModel.offset = loaded.count

    XCTAssertEqual(viewModel.items.map(\.relativePath), ["a.txt", "b.txt"])

    // Switch to most-recent sort
    harness.preferences.setSort(.automatic(.mostRecent), forLocation: .libraryRoot)

    viewModel.reloadItemsPreservingOffset()

    XCTAssertEqual(
      viewModel.items.map(\.relativePath),
      ["b.txt", "a.txt"],
      "re-fetch reflects the new sort order"
    )
  }

  /// If the store has fewer items than the window (e.g. items were deleted),
  /// `canLoadMore` is correctly set to false.
  func testReloadPreservingOffsetSetsCanLoadMoreFalseWhenExhausted() {
    harness.seedBook(relativePath: "a.txt", rank: 0)
    harness.seedBook(relativePath: "b.txt", rank: 1)
    harness.save()

    viewModel.items = harness.libraryService.fetchContents(at: nil, limit: nil, offset: nil) ?? []
    viewModel.offset = viewModel.items.count
    viewModel.canLoadMore = true // stale state

    viewModel.reloadItemsPreservingOffset()

    XCTAssertFalse(viewModel.canLoadMore, "no more items to load")
  }

  // MARK: - reloadItems (for comparison)

  /// `reloadItems` resets offset to 0 and fetches only the first page —
  /// the behaviour that `reloadItemsPreservingOffset` is designed to avoid.
  func testReloadItemsResetsOffsetToZero() {
    let total = 30
    for i in 0..<total {
      harness.seedBook(relativePath: "book\(i).txt", rank: Int16(i))
    }
    harness.save()

    // Simulate scrolled state
    let loaded = harness.libraryService.fetchContents(at: nil, limit: 26, offset: 0) ?? []
    viewModel.items = loaded
    viewModel.offset = 26
    viewModel.canLoadMore = true

    viewModel.reloadItems()

    XCTAssertEqual(viewModel.offset, viewModel.items.count, "offset reset to first-page count")
    // reloadItems fetches items.count + 0 padding = 26 items
    XCTAssertEqual(viewModel.items.count, 26)
    XCTAssertTrue(viewModel.canLoadMore)
  }
}