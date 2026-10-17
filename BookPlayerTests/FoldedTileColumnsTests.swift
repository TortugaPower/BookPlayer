//
//  FoldedTileColumnsTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
import XCTest

/// The grid's columns across a fold: the iPhone Duo's in the book pose, a 40 pt band 439.5 pt into
/// an 835 pt wide grid, which leaves 439.5 pt before it and 355.5 pt after it
final class FoldedTileColumnsTests: XCTestCase {
  private let duoBookPose = (width: CGFloat(835), fold: CGFloat(439.5)...CGFloat(479.5))

  func testCoversFillBothSidesAroundTheFold() throws {
    let columns = try XCTUnwrap(
      FoldedTileColumns(width: duoBookPose.width, fold: duoBookPose.fold, minimumWidth: 140, spacing: 8)
    )

    XCTAssertEqual(columns.leadingCount, 3)
    XCTAssertEqual(columns.trailingCount, 2)
    XCTAssertEqual(columns.tileWidth, 141)
    XCTAssertEqual(columns.foldGap, 40)
    // The last column before the fold ends where it starts, the first after it where it ends
    XCTAssertEqual(columns.leadingInset + 3 * 141 + 2 * 8, duoBookPose.fold.lowerBound)
    XCTAssertEqual(columns.leadingInset + 3 * 141 + 2 * 8 + 40, duoBookPose.fold.upperBound)
  }

  func testCardsKeepOneWidthAndLeaveTheRestAtTheOuterEdge() throws {
    let columns = try XCTUnwrap(
      FoldedTileColumns(width: duoBookPose.width, fold: duoBookPose.fold, minimumWidth: 150, spacing: 16)
    )

    XCTAssertEqual(columns.leadingCount, 2)
    XCTAssertEqual(columns.trailingCount, 2)
    // The narrower side sets the width for both, so the rows line up
    XCTAssertEqual(columns.tileWidth, 169)
    XCTAssertEqual(columns.leadingInset, 85.5)
    XCTAssertEqual(columns.width, 4 * 169 + 2 * 16 + 40)
  }

  func testTheFoldIsTheOnlyWiderGap() throws {
    let columns = try XCTUnwrap(
      FoldedTileColumns(width: duoBookPose.width, fold: duoBookPose.fold, minimumWidth: 140, spacing: 8)
    )

    XCTAssertEqual(columns.gridItems.map(\.spacing), [8, 8, 40, 8, 8])
  }

  func testNoColumnsWhenASideCantHoldATile() {
    XCTAssertNil(FoldedTileColumns(width: 300, fold: 50...90, minimumWidth: 100, spacing: 8))
    XCTAssertNil(FoldedTileColumns(width: 300, fold: 210...250, minimumWidth: 100, spacing: 8))
  }
}
