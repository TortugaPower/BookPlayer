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
  func testLoadItemFromShowPlayer() {
    let playerMock = PlayerManagerProtocolMock()
    playerMock.currentItemPublisherReturnValue = Just(PlayableItem.mock).eraseToAnyPublisher()
    playerMock.hasLoadedBookReturnValue = false
    let sut = MiniPlayerViewModel(playerManager: playerMock)
    
    let expectation = XCTestExpectation(description: "Waiting for transition capture")
    var capturedTransition = false
    
    sut.onTransition = { route in
      if case .loadItem = route {
        capturedTransition = true
        expectation.fulfill()
      }
    }
    
    sut.showPlayer()
    
    wait(for: [expectation], timeout: 0.5)
    XCTAssert(capturedTransition == true)
  }
  
  func testShowPlayer() {
    let playerMock = PlayerManagerProtocolMock()
    playerMock.currentItemPublisherReturnValue = Just(nil).eraseToAnyPublisher()
    playerMock.hasLoadedBookReturnValue = true
    let sut = MiniPlayerViewModel(playerManager: playerMock)
    
    let expectation = XCTestExpectation(description: "Waiting for transition capture")
    var capturedTransition = false
    
    sut.onTransition = { route in
      if case .showPlayer = route {
        capturedTransition = true
        expectation.fulfill()
      }
    }
    
    sut.showPlayer()
    
    wait(for: [expectation], timeout: 0.5)
    XCTAssert(capturedTransition == true)
  }
  
  func testLoadItemFromPlayPause() {
    let playerMock = PlayerManagerProtocolMock()
    playerMock.currentItemPublisherReturnValue = Just(PlayableItem.mock).eraseToAnyPublisher()
    playerMock.hasLoadedBookReturnValue = false
    
    let sut = MiniPlayerViewModel(playerManager: playerMock)
    
    let expectation = XCTestExpectation(description: "Waiting for transition capture")
    var capturedTransition = false
    
    sut.onTransition = { route in
      if case .loadItem = route {
        capturedTransition = true
        expectation.fulfill()
      }
    }
    
    sut.handlePlayPauseAction()
    
    wait(for: [expectation], timeout: 0.5)
    XCTAssert(capturedTransition == true)
    XCTAssert(playerMock.playPauseCalled == false)
  }
  
  func testPlayPause() {
    let playerMock = PlayerManagerProtocolMock()
    playerMock.currentItemPublisherReturnValue = Just(nil).eraseToAnyPublisher()
    playerMock.hasLoadedBookReturnValue = true
    
    let sut = MiniPlayerViewModel(playerManager: playerMock)
    sut.handlePlayPauseAction()
    
    XCTAssert(playerMock.playPauseCalled == true)
  }
}
