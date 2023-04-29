//
//  MiniPlayerViewModelTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 11/20/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class MiniPlayerViewModelTests: XCTestCase {
  var sut: MiniPlayerViewModel!
  var playerMock: PlayerManagerMock!

  override func setUp() {
    self.playerMock = PlayerManagerMock()
    self.sut = MiniPlayerViewModel(playerManager: self.playerMock, lastPlayedItem: nil)
  }

  func testShowPlayer() {
    let expectation = XCTestExpectation(description: "Waiting for transition capture")
    var capturedTransition = false

    self.sut.onTransition = { route in
      if case .showPlayer = route {
        capturedTransition = true
        expectation.fulfill()
      }
    }

    self.sut.showPlayer()

    wait(for: [expectation], timeout: 0.5)
    XCTAssert(capturedTransition == true)
  }

  func testPlayPause() {
    self.sut.handlePlayPauseAction()

    XCTAssert(self.playerMock.didPlayPause == true)
  }
}
