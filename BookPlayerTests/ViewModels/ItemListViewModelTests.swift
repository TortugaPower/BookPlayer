//
//  ItemListViewModelTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
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
}
