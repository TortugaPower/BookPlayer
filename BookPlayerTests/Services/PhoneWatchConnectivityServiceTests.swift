//
//  PhoneWatchConnectivityServiceTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import WatchConnectivity
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// WatchConnectivity calls the service on a queue of its own, while the library it reads for the
/// watch lives on the main actor (BOOKPLAYER-13KS, -13KB, -13GR crashed reading it off main)
@MainActor
final class PhoneWatchConnectivityServiceTests: XCTestCase {
  /// What the callbacks saw, written from whichever thread they ran on
  private final class Recorder: @unchecked Sendable {
    var readTheLibraryOnMain: Bool?
    var reply: Data?
  }

  func testTheWatchsRefreshReadsTheLibraryOnMainAndReplies() async throws {
    let recorder = Recorder()
    let libraryService = LibraryServiceProtocolMock()
    libraryService.getLastPlayedItemsLimitClosure = { _ in
      recorder.readTheLibraryOnMain = Thread.isMainThread
      return []
    }
    let playerManager = PlayerManagerProtocolMock()
    playerManager.currentSpeed = 1
    let sut = PhoneWatchConnectivityService(
      libraryService: libraryService,
      playbackService: PlaybackServiceProtocolMock(),
      playerManager: playerManager
    )
    /// As the watch sends it
    let request = try JSONEncoder().encode(["command": Command.refresh.rawValue])
    let replied = expectation(description: "the watch gets its context")

    DispatchQueue.global().async {
      sut.session(WCSession.default, didReceiveMessageData: request) { data in
        recorder.reply = data
        replied.fulfill()
      }
    }

    await fulfillment(of: [replied], timeout: 2)
    XCTAssertEqual(recorder.readTheLibraryOnMain, true)
    let reply = try XCTUnwrap(recorder.reply)
    XCTAssertEqual(try JSONDecoder().decode(WatchApplicationContext.self, from: reply).rate, 1)
  }
}
