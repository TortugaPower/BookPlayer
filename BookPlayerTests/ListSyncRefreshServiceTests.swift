//
//  ListSyncRefreshServiceTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// First coverage for the one entry point every list refresh goes through. What it pins is
/// the ORDER: the media-server pull runs after the cloud sync of the same level (they write
/// on different contexts and must never overlap), for the same path, and regardless of how
/// the cloud step ended — the servers are independent hosts.
final class ListSyncRefreshServiceTests: XCTestCase {
  /// Shared by the cloud mock and the pull stub so a test can read the sequence back.
  private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [String] = []

    var events: [String] {
      lock.lock()
      defer { lock.unlock() }
      return _events
    }

    func record(_ event: String) {
      lock.lock()
      _events.append(event)
      lock.unlock()
    }
  }

  private final class ProgressRefreshStub: ExternalProgressRefreshing {
    let recorder: Recorder

    init(recorder: Recorder) {
      self.recorder = recorder
    }

    func refreshItems(at relativePath: String?) async {
      recorder.record("pull:\(relativePath ?? "root")")
    }
  }

  private var recorder: Recorder!
  private var syncService: SyncServiceProtocolMock!
  private var preferencesService: PreferencesSyncServiceProtocolMock!
  private var sut: ListSyncRefreshService!

  override func setUp() {
    super.setUp()
    recorder = Recorder()
    syncService = SyncServiceProtocolMock()
    // The first sync already ran: folder levels pull normally
    syncService.hasRunFirstSync = true
    syncService.syncListContentsAtClosure = { [recorder] path in
      recorder?.record("cloud:\(path ?? "root")")
    }
    preferencesService = PreferencesSyncServiceProtocolMock()
    sut = ListSyncRefreshService(
      playerManager: PlayerManagerProtocolMock(),
      syncService: syncService,
      // Never reached: the loader only runs on the two last-book errors, which no test throws.
      playerLoaderService: PlayerLoaderService(),
      preferencesService: preferencesService,
      externalProgressService: ProgressRefreshStub(recorder: recorder)
    )
  }

  func testPullsTheLevelAfterItsCloudSync() async throws {
    try await sut.syncList(at: "Author/Series")

    XCTAssertEqual(recorder.events, ["cloud:Author/Series", "pull:Author/Series"])
    XCTAssertEqual(preferencesService.pullFromServerForceCallsCount, 1)
  }

  /// A cloud failure (network, server) is logged and swallowed; the media servers still get asked.
  func testPullStillRunsWhenTheCloudSyncFails() async throws {
    syncService.syncListContentsAtThrowableError = URLError(.notConnectedToInternet)

    try await sut.syncList(at: "Author/Series")

    XCTAssertEqual(recorder.events, ["pull:Author/Series"], "the closure never ran; the pull did")
    XCTAssertEqual(preferencesService.pullFromServerForceCallsCount, 1)
  }

  /// Until the first sync has registered this device's items, a folder's listing would delete
  /// the ones the server hasn't seen (books imported while sync was off): its cloud step waits
  func testFolderCloudSync_waitsForTheFirstSync() async throws {
    syncService.hasRunFirstSync = false

    try await sut.syncList(at: "Author/Series")

    XCTAssertEqual(recorder.events, ["pull:Author/Series"])
    XCTAssertEqual(preferencesService.pullFromServerForceCallsCount, 1)
  }

  /// The root refresh asks for the weekly / became-PRO pass, without waiting on it
  func testRootRefresh_asksForTheMissingItemsPass() async throws {
    let asked = expectation(description: "pass asked")
    syncService.scheduleMissingItemsIfNeededClosure = { asked.fulfill() }

    try await sut.syncList(at: nil)

    await fulfillment(of: [asked], timeout: 1)
    XCTAssertEqual(recorder.events.first, "cloud:root")
  }

  func testFolderRefresh_neverAsksForThePass() async throws {
    let asked = expectation(description: "pass asked")
    asked.isInverted = true
    syncService.scheduleMissingItemsIfNeededClosure = { asked.fulfill() }

    try await sut.syncList(at: "Author")

    await fulfillment(of: [asked], timeout: 0.3)
  }
}
