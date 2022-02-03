//
//  PlayableItemTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 3/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class PlayableItemTests: XCTestCase {
  var sut: PlayableItem!

  private func generatePlayableItem() {

  }

  override func setUp() {
    let testChapter = PlayableChapter(
      title: "test chapter",
      author: "test author",
      start: 0,
      duration: 50,
      relativePath: "",
      index: 1
    )
    let testChapter2 = PlayableChapter(
      title: "test chapter2",
      author: "test author",
      start: 51,
      duration: 100,
      relativePath: "",
      index: 1
    )
    self.sut = PlayableItem(
      title: "test book",
      author: "test author",
      chapters: [testChapter, testChapter2],
      currentTime: 0,
      duration: 100,
      relativePath: "",
      percentCompleted: 10,
      isFinished: false,
      useChapterTimeContext: false
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
}
