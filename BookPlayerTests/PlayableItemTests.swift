//
//  PlayableItemTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 3/2/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class PlayableItemTests: XCTestCase {
  var sut: PlayableItem!

  override func setUp() {
    let testChapter = PlayableChapter(
      title: "test chapter",
      author: "test author",
      start: 0,
      duration: 50,
      relativePath: "",
      remoteURL: nil,
      index: 1
    )
    let testChapter2 = PlayableChapter(
      title: "test chapter2",
      author: "test author",
      start: 51,
      duration: 100,
      relativePath: "",
      remoteURL: nil,
      index: 1
    )
    self.sut = PlayableItem(
      title: "test book",
      author: "test author",
      chapters: [testChapter, testChapter2],
      currentTime: 0,
      duration: 100,
      relativePath: "",
      uuid: "LEGACY_UUID",
      parentFolder: nil,
      percentCompleted: 10,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
  }

  func testMaxTimeInContext() {
    let totalDurationInChapter = sut.maxTimeInContext(
      prefersChapterContext: true,
      prefersRemainingTime: false,
      at: 2
    )

    XCTAssert(totalDurationInChapter == 50)

    let totalDurationInBook = sut.maxTimeInContext(
      prefersChapterContext: false,
      prefersRemainingTime: false,
      at: 2
    )

    XCTAssert(totalDurationInBook == 100)

    let remainingTimeInChapter = sut.maxTimeInContext(
      prefersChapterContext: true,
      prefersRemainingTime: true,
      at: 2
    )

    XCTAssert(remainingTimeInChapter == -25)

    let remainingTimeInBook = sut.maxTimeInContext(
      prefersChapterContext: false,
      prefersRemainingTime: true,
      at: 2
    )

    XCTAssert(remainingTimeInBook == -50)
  }

  // MARK: - isNearChapterStart

  func testIsNearChapterStartWithinThreshold() {
    sut.currentChapter = sut.chapters[0]  // starts at 0
    sut.currentTime = 2

    XCTAssertTrue(sut.isNearChapterStart)
  }

  func testIsNearChapterStartAtChapterStart() {
    sut.currentChapter = sut.chapters[1]  // starts at 51
    sut.currentTime = 51

    XCTAssertTrue(sut.isNearChapterStart)
  }

  func testIsNotNearChapterStartAtThresholdBoundary() {
    /// Exactly `chapterStartThreshold` (3s) past the start is NOT near the start
    sut.currentChapter = sut.chapters[1]  // starts at 51
    sut.currentTime = 54

    XCTAssertFalse(sut.isNearChapterStart)
  }

  func testIsNotNearChapterStartMidChapter() {
    sut.currentChapter = sut.chapters[1]  // starts at 51
    sut.currentTime = 100

    XCTAssertFalse(sut.isNearChapterStart)
  }

  // MARK: - Chapter navigation

  /// A single-file book whose chapter list is exactly `chapters`.
  private func makeItem(chapters: [PlayableChapter]) -> PlayableItem {
    PlayableItem(
      title: "test book",
      author: "test author",
      chapters: chapters,
      currentTime: 0,
      duration: chapters.last?.end ?? 0,
      relativePath: "book.m4b",
      uuid: "LEGACY_UUID",
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
  }

  private func makeChapter(
    _ title: String,
    index: Int16,
    start: TimeInterval,
    duration: TimeInterval = 100
  ) -> PlayableChapter {
    PlayableChapter(
      title: title,
      author: "test author",
      start: start,
      duration: duration,
      relativePath: "book.m4b",
      remoteURL: nil,
      index: index
    )
  }

  func testChapterNavigationWalksTheListInOrder() {
    let first = makeChapter("one", index: 1, start: 0)
    let second = makeChapter("two", index: 2, start: 100)
    let third = makeChapter("three", index: 3, start: 200)
    let item = makeItem(chapters: [first, second, third])

    XCTAssertNil(item.previousChapter(before: first))
    XCTAssertEqual(item.nextChapter(after: first), second)
    XCTAssertEqual(item.previousChapter(before: second), first)
    XCTAssertEqual(item.nextChapter(after: second), third)
    XCTAssertEqual(item.previousChapter(before: third), second)
    XCTAssertNil(item.nextChapter(after: third))

    XCTAssertFalse(item.hasChapter(before: first))
    XCTAssertTrue(item.hasChapter(after: first))
    XCTAssertTrue(item.hasChapter(before: third))
    XCTAssertFalse(item.hasChapter(after: third))
  }

  func testChapterNavigationDoesNotTrustZeroBasedIndices() {
    /// The stored `index` is metadata, not an array offset. A 0-based list used to
    /// send `previousChapter(before: second)` to `chapters[-1]`.
    let first = makeChapter("one", index: 0, start: 0)
    let second = makeChapter("two", index: 1, start: 100)
    let third = makeChapter("three", index: 2, start: 200)
    let item = makeItem(chapters: [first, second, third])

    XCTAssertNil(item.previousChapter(before: first))
    XCTAssertEqual(item.nextChapter(after: first), second)
    XCTAssertEqual(item.previousChapter(before: second), first)
    XCTAssertEqual(item.nextChapter(after: second), third)
    XCTAssertEqual(item.previousChapter(before: third), second)
    XCTAssertNil(item.nextChapter(after: third))
  }

  func testChapterNavigationWithDuplicateIndices() {
    /// Two chapters sharing `index` 1 (the shape of this file's own `setUp` fixture) used to
    /// send `previousChapter(before: second)` to `chapters[-1]`.
    let first = makeChapter("one", index: 1, start: 0)
    let second = makeChapter("two", index: 1, start: 100)
    let item = makeItem(chapters: [first, second])

    XCTAssertNil(item.previousChapter(before: first))
    XCTAssertEqual(item.nextChapter(after: first), second)
    XCTAssertEqual(item.previousChapter(before: second), first)
    XCTAssertNil(item.nextChapter(after: second))
  }

  func testChapterNavigationWithStaleChapterResolvesByTime() {
    /// After "reload chapters" the player item is rebuilt, but a `PlayableChapter` captured
    /// from the old item can still be handed in. It is not `==` to any new chapter, so the old
    /// `chapter == chapters.first` guard failed and `Int(chapter.index) - 2` went negative.
    let first = makeChapter("Chapter 1", index: 1, start: 0)
    let second = makeChapter("Chapter 2", index: 2, start: 100)
    let third = makeChapter("Chapter 3", index: 3, start: 200)
    let item = makeItem(chapters: [first, second, third])

    let staleFirst = makeChapter("old single chapter", index: 1, start: 0, duration: 300)
    XCTAssertNil(item.previousChapter(before: staleFirst))
    XCTAssertEqual(item.nextChapter(after: staleFirst), second)

    let staleMiddle = makeChapter("old chapter", index: 7, start: 150, duration: 10)
    XCTAssertEqual(item.previousChapter(before: staleMiddle), first)
    XCTAssertEqual(item.nextChapter(after: staleMiddle), third)
  }

  func testChapterNavigationWithChapterOutsideTheBookReturnsNil() {
    /// A chapter from another book, or one past the end of this one, has no neighbours here.
    /// `nextChapter` used to index `chapters[Int(chapter.index)]` and overrun the array.
    let first = makeChapter("one", index: 1, start: 0)
    let second = makeChapter("two", index: 2, start: 100)
    let item = makeItem(chapters: [first, second])

    let foreign = makeChapter("elsewhere", index: 99, start: 5_000)
    XCTAssertNil(item.previousChapter(before: foreign))
    XCTAssertNil(item.nextChapter(after: foreign))
    XCTAssertFalse(item.hasChapter(before: foreign))
    XCTAssertFalse(item.hasChapter(after: foreign))
  }

  func testChapterNavigationOnSingleChapterBook() {
    let only = makeChapter("only", index: 1, start: 0)
    let item = makeItem(chapters: [only])

    XCTAssertNil(item.previousChapter(before: only))
    XCTAssertNil(item.nextChapter(after: only))
  }

  func testPlaybackServiceNextChapterMatchesItemNavigation() {
    let first = makeChapter("one", index: 0, start: 0)
    let second = makeChapter("two", index: 1, start: 100)
    let item = makeItem(chapters: [first, second])
    let service = PlaybackService()

    XCTAssertEqual(service.getNextChapter(from: item, after: first), second)
    XCTAssertNil(service.getNextChapter(from: item, after: second))
  }
}
