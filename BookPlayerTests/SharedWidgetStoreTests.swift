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

  /// `store`/`removeItems` mutate asynchronously on a serial queue, so flush before asserting.
  private func prune(_ paths: [String]) {
    SharedWidgetStore.removeItems(matching: paths)
    SharedWidgetStore.waitForPendingMutations()
  }

  private func store(_ relativePath: String) {
    SharedWidgetStore.store(makeItem(relativePath: relativePath))
    SharedWidgetStore.waitForPendingMutations()
  }

  // MARK: - removeItems

  func testRemoveExactBookMatch() {
    seedSnapshot(["Book1", "Folder/Book2", "Folder/Book3", "Foobar"])

    prune(["Book1"])

    XCTAssertEqual(snapshotPaths(), ["Folder/Book2", "Folder/Book3", "Foobar"])
  }

  func testRemoveFolderPrunesDescendants() {
    seedSnapshot(["Book1", "Folder/Book2", "Folder/Book3", "Foobar"])

    prune(["Folder"])

    // Folder's children removed; Book1 and the similarly-named Foobar are retained.
    XCTAssertEqual(snapshotPaths(), ["Book1", "Foobar"])
  }

  func testRemoveDoesNotMatchSiblingPrefix() {
    seedSnapshot(["Foo", "Foobar"])

    // Deleting "Foo" must not prune "Foobar" (only exact match or "Foo/" descendants).
    prune(["Foo"])

    XCTAssertEqual(snapshotPaths(), ["Foobar"])
  }

  func testRemoveWithNoMatchLeavesSnapshotUnchanged() {
    seedSnapshot(["Book1", "Book2"])

    prune(["DoesNotExist"])

    XCTAssertEqual(snapshotPaths(), ["Book1", "Book2"])
  }

  func testRemoveWithEmptyInputIsNoOp() {
    seedSnapshot(["Book1"])

    prune([])

    XCTAssertEqual(snapshotPaths(), ["Book1"])
  }

  func testRemoveOnEmptySnapshotIsNoOp() {
    prune(["Book1"])

    XCTAssertEqual(snapshotPaths(), [])
  }

  func testRemoveMultiplePaths() {
    seedSnapshot(["Book1", "Book2", "Book3"])

    prune(["Book1", "Book3"])

    XCTAssertEqual(snapshotPaths(), ["Book2"])
  }

  // MARK: - store

  func testStorePrependsAndDedupes() {
    seedSnapshot(["Book1", "Book2"])

    store("Book2")

    // Book2 moves to the front; no duplicate entry.
    XCTAssertEqual(snapshotPaths(), ["Book2", "Book1"])
  }

  func testStoreCapsAtTenItems() {
    seedSnapshot((1...10).map { "Book\($0)" })

    store("BookNew")

    let paths = snapshotPaths()
    XCTAssertEqual(paths.count, 10)
    XCTAssertEqual(paths.first, "BookNew")
    XCTAssertFalse(paths.contains("Book10"))
  }

  // MARK: - Concurrency

  /// Smoke test: hammer `store`/`removeItems` from many threads at once. The serial
  /// mutation queue must keep the snapshot well-formed — decodable, within the cap, and
  /// free of duplicate paths — with no torn read-modify-write. (Probabilistic, not a proof.)
  func testConcurrentMutationsKeepSnapshotWellFormed() {
    seedSnapshot((1...5).map { "Book\($0)" })

    let group = DispatchGroup()
    for index in 0..<100 {
      DispatchQueue.global().async(group: group) {
        if index.isMultiple(of: 2) {
          SharedWidgetStore.store(self.makeItem(relativePath: "Extra\(index)"))
        } else {
          SharedWidgetStore.removeItems(matching: ["Book\((index % 5) + 1)"])
        }
      }
    }
    group.wait()
    SharedWidgetStore.waitForPendingMutations()

    let paths = snapshotPaths()
    XCTAssertLessThanOrEqual(paths.count, 10, "store must keep the snapshot within the cap")
    XCTAssertEqual(Set(paths).count, paths.count, "no duplicate relativePaths")
  }
}
