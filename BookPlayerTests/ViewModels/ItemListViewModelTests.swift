//
//  ItemListViewModelTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
import BookPlayerKit
import XCTest

/// The grid's reorder names items; the library reorders by the offsets the list's `onMove` gives
@MainActor
final class ItemListViewModelTests: XCTestCase {
  private let order = ["a", "b", "c", "d"]

  private func moved(_ ids: [String], before targetID: String?) -> [String]? {
    guard
      let (source, destination) = ItemListViewModel.moveOffsets(of: ids, before: targetID, in: order)
    else { return nil }

    var reordered = order
    reordered.move(fromOffsets: source, toOffset: destination)
    return reordered
  }

  func testMoveForwardLandsBeforeTheTarget() {
    XCTAssertEqual(moved(["a"], before: "d"), ["b", "c", "a", "d"])
  }

  func testMoveBackwardLandsBeforeTheTarget() {
    XCTAssertEqual(moved(["d"], before: "b"), ["a", "d", "b", "c"])
  }

  func testMoveToTheEnd() {
    XCTAssertEqual(moved(["a"], before: nil), ["b", "c", "d", "a"])
  }

  func testMoveSeveralKeepsTheirOrder() {
    XCTAssertEqual(moved(["c", "a"], before: nil), ["b", "d", "a", "c"])
  }

  func testMoveSeveralApartBeforeOneBetweenThem() {
    XCTAssertEqual(moved(["a", "d"], before: "c"), ["b", "a", "d", "c"])
  }

  func testMoveSeveralBeforeOneOfThemIsNoMove() {
    XCTAssertNil(ItemListViewModel.moveOffsets(of: ["b", "c"], before: "c", in: order))
  }

  func testDropInPlaceIsNoMove() {
    // A tile dropped where it was must not turn the sort into Custom
    XCTAssertNil(ItemListViewModel.moveOffsets(of: ["b"], before: "c", in: order))
    XCTAssertNil(ItemListViewModel.moveOffsets(of: ["d"], before: nil, in: order))
  }

  func testUnknownItemsAreNoMove() {
    XCTAssertNil(ItemListViewModel.moveOffsets(of: ["x"], before: "a", in: order))
    XCTAssertNil(ItemListViewModel.moveOffsets(of: ["a"], before: "x", in: order))
  }

  // MARK: - Redrawing for download events

  /// A download ending redraws the lists that show its file, so their menus offer the right action
  func testADownloadedFileConcernsTheListsShowingIt() {
    let root = [item("The Housemaid.m4b", type: .book), item("Volume", type: .bound), item("Folder", type: .folder)]

    XCTAssertTrue(ItemListViewModel.listShows("The Housemaid.m4b", in: root))
    XCTAssertTrue(ItemListViewModel.listShows("Volume/part 1.mp3", in: root), "a bound book's part")
    XCTAssertTrue(ItemListViewModel.listShows("Folder/Book.m4b", in: root), "a folder's book")
    XCTAssertFalse(ItemListViewModel.listShows("Volume 2/part 1.mp3", in: root), "only a real path prefix")
    XCTAssertFalse(ItemListViewModel.listShows("Elsewhere/The Housemaid.m4b", in: root))

    // The folder's own list, which a download resumed after a relaunch doesn't name (it's filed under
    // the top-level folder): matched by the file's path
    XCTAssertTrue(ItemListViewModel.listShows("Folder/Book.m4b", in: [item("Folder/Book.m4b", type: .book)]))
  }

  private func item(_ relativePath: String, type: SimpleItemType) -> SimpleLibraryItem {
    SimpleLibraryItem(
      title: relativePath,
      details: "",
      speed: 1,
      currentTime: 0,
      duration: 0,
      percentCompleted: 0,
      isFinished: false,
      relativePath: relativePath,
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: relativePath,
      lastPlayDate: nil,
      type: type,
      uuid: UUID().uuidString
    )
  }
}
