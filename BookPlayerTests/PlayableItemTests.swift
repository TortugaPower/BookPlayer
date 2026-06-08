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
}
