//
//  SharedWidgetStoreTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 2/6/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayerKit
import Foundation
import XCTest

/// Covers `SharedWidgetStore` snapshot mutation: prune matching rules and `store`
/// dedupe/cap. The debounced widget reload is not asserted here — it calls the
/// non-mockable `WidgetCenter.shared` singleton on a deferred main-queue work item.
class SharedWidgetStoreTests: XCTestCase {
  private let key = Constants.UserDefaults.sharedWidgetLastPlayedItems

  override func setUp() {
    UserDefaults.sharedDefaults.removeObject(forKey: key)
  }

  override func tearDown() {
    UserDefaults.sharedDefaults.removeObject(forKey: key)
  }

  // MARK: - Helpers

  private func makeItem(relativePath: String) -> PlayableItem {
    let chapter = PlayableChapter(
      title: relativePath,
      author: "author",
      start: 0,
      duration: 100,
      relativePath: relativePath,
      remoteURL: nil,
      index: 0
    )
    return PlayableItem(
      title: relativePath,
      author: "author",
      chapters: [chapter],
      currentTime: 0,
      duration: 100,
      relativePath: relativePath,
      uuid: relativePath,
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
  }

  private func seedSnapshot(_ relativePaths: [String]) {
    let items = relativePaths.map(makeItem(relativePath:))
    let data = try! JSONEncoder().encode(items)
    UserDefaults.sharedDefaults.set(data, forKey: key)
  }

  private func snapshotPaths() -> [String] {
    guard
      let data = UserDefaults.sharedDefaults.data(forKey: key),
      let items = try? JSONDecoder().decode([PlayableItem].self, from: data)
    else { return [] }

    return items.map(\.relativePath)
  }

  // MARK: - removeItems

  func testRemoveExactBookMatch() {
    seedSnapshot(["Book1", "Folder/Book2", "Folder/Book3", "Foobar"])

    let changed = SharedWidgetStore.removeItems(matching: ["Book1"])

    XCTAssertTrue(changed)
    XCTAssertEqual(snapshotPaths(), ["Folder/Book2", "Folder/Book3", "Foobar"])
  }

  func testRemoveFolderPrunesDescendants() {
    seedSnapshot(["Book1", "Folder/Book2", "Folder/Book3", "Foobar"])

    let changed = SharedWidgetStore.removeItems(matching: ["Folder"])

    XCTAssertTrue(changed)
    // Folder's children removed; Book1 and the similarly-named Foobar are retained.
    XCTAssertEqual(snapshotPaths(), ["Book1", "Foobar"])
  }

  func testRemoveDoesNotMatchSiblingPrefix() {
    seedSnapshot(["Foo", "Foobar"])

    // Deleting "Foo" must not prune "Foobar" (only exact match or "Foo/" descendants).
    let changed = SharedWidgetStore.removeItems(matching: ["Foo"])

    XCTAssertTrue(changed)
    XCTAssertEqual(snapshotPaths(), ["Foobar"])
  }

  func testRemoveWithNoMatchLeavesSnapshotUnchanged() {
    seedSnapshot(["Book1", "Book2"])
    let before = UserDefaults.sharedDefaults.data(forKey: key)

    let changed = SharedWidgetStore.removeItems(matching: ["DoesNotExist"])

    XCTAssertFalse(changed)
    XCTAssertEqual(UserDefaults.sharedDefaults.data(forKey: key), before)
  }

  func testRemoveWithEmptyInputIsNoOp() {
    seedSnapshot(["Book1"])

    XCTAssertFalse(SharedWidgetStore.removeItems(matching: []))
    XCTAssertEqual(snapshotPaths(), ["Book1"])
  }

  func testRemoveOnEmptySnapshotIsNoOp() {
    XCTAssertFalse(SharedWidgetStore.removeItems(matching: ["Book1"]))
    XCTAssertEqual(snapshotPaths(), [])
  }

  func testRemoveMultiplePaths() {
    seedSnapshot(["Book1", "Book2", "Book3"])

    let changed = SharedWidgetStore.removeItems(matching: ["Book1", "Book3"])

    XCTAssertTrue(changed)
    XCTAssertEqual(snapshotPaths(), ["Book2"])
  }

  // MARK: - store

  func testStorePrependsAndDedupes() {
    seedSnapshot(["Book1", "Book2"])

    SharedWidgetStore.store(makeItem(relativePath: "Book2"))

    // Book2 moves to the front; no duplicate entry.
    XCTAssertEqual(snapshotPaths(), ["Book2", "Book1"])
  }

  func testStoreCapsAtTenItems() {
    seedSnapshot((1...10).map { "Book\($0)" })

    SharedWidgetStore.store(makeItem(relativePath: "BookNew"))

    let paths = snapshotPaths()
    XCTAssertEqual(paths.count, 10)
    XCTAssertEqual(paths.first, "BookNew")
    XCTAssertFalse(paths.contains("Book10"))
  }
}
