//
//  QueuedTaskDisplayTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// The sectioned Queued Tasks screen is pure shaping over the engine's task list: lane
/// order, per-row copy and icon, and which rows follow byte progress.
final class QueuedTaskDisplayTests: XCTestCase {
  private func task(
    _ id: String,
    lane: String,
    jobType: SyncJobType = .externalUpdate,
    uuid: String = "",
    relativePath: String = ""
  ) -> ConcurrentSyncTask {
    ConcurrentSyncTask(
      id: id,
      queueKey: lane,
      jobType: jobType,
      parameters: [:],
      uuid: uuid,
      relativePath: relativePath
    )
  }

  func testGroupedByLane_syncFirstThenAlphabetical_keepingEngineOrder() {
    let tasks = [
      task("j2", lane: "jellyfin"),
      task("u1", lane: TaskQueueKey.uploadFile, jobType: .uploadFile),
      task("a1", lane: "audiobookshelf"),
      task("s1", lane: TaskQueueKey.sync, jobType: .update),
      task("j1", lane: "jellyfin"),
    ]

    let sections = tasks.groupedByLane()

    XCTAssertEqual(
      sections.map(\.queueKey),
      [TaskQueueKey.sync, "audiobookshelf", "jellyfin", TaskQueueKey.uploadFile]
    )
    XCTAssertEqual(sections[2].tasks.map(\.id), ["j2", "j1"], "a lane keeps the engine's order")
  }

  func testGroupedByLane_drainedLanesHaveNoSection() {
    XCTAssertTrue([ConcurrentSyncTask]().groupedByLane().isEmpty)
    XCTAssertEqual([task("j1", lane: "jellyfin")].groupedByLane().map(\.queueKey), ["jellyfin"])
  }

  func testDisplayTitle_perJobType() {
    XCTAssertEqual(
      task("s", lane: TaskQueueKey.sync, jobType: .matchUuid).displayTitle,
      "sync_library_title".localized
    )
    XCTAssertEqual(
      task("s", lane: TaskQueueKey.sync, jobType: .update, relativePath: "Author/Book.m4b").displayTitle,
      "Author/Book.m4b"
    )
    XCTAssertEqual(
      task("u", lane: TaskQueueKey.uploadFile, jobType: .uploadFile).displayTitle,
      "task_uploading_file_label".localized
    )
    XCTAssertEqual(
      task("j", lane: "jellyfin").displayTitle,
      String(format: "task_updating_progress_label".localized, "Jellyfin")
    )
  }

  func testDisplayImageName_perJobType() {
    XCTAssertEqual(
      task("u", lane: TaskQueueKey.uploadFile, jobType: .uploadFile).displayImageName,
      "square.and.arrow.up.badge.clock"
    )
    XCTAssertEqual(task("s", lane: TaskQueueKey.sync, jobType: .setBookmark).displayImageName, "bookmark")
    XCTAssertEqual(
      task("s", lane: TaskQueueKey.sync, jobType: .matchUuid).displayImageName,
      "app.connected.to.app.below.fill"
    )
    XCTAssertEqual(task("j", lane: "jellyfin").displayImageName, "arrow.2.circlepath")
  }

  func testTracksByteProgress_onlyForFileUploads() {
    XCTAssertTrue(task("u", lane: TaskQueueKey.uploadFile, jobType: .uploadFile).tracksByteProgress)
    XCTAssertTrue(task("s", lane: TaskQueueKey.sync, jobType: .upload).tracksByteProgress)
    XCTAssertFalse(task("s", lane: TaskQueueKey.sync, jobType: .update).tracksByteProgress)
    XCTAssertFalse(task("j", lane: "jellyfin").tracksByteProgress)
  }

  /// Rows and `.uploadProgressUpdated` must agree on the key: a real uuid, else the path.
  func testProgressKey_matchesTheProgressNotificationKey() {
    let uuid = UUID().uuidString
    XCTAssertEqual(task("a", lane: TaskQueueKey.sync, uuid: uuid, relativePath: "A.m4b").progressKey, uuid)
    XCTAssertEqual(
      task("b", lane: TaskQueueKey.sync, uuid: Constants.uuidPlaceholder, relativePath: "B.m4b").progressKey,
      "B.m4b"
    )
  }
}
