//
//  SyncPauseReportingTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import Sentry
import SwiftData
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// Sentry reporting and the Report attachment for parked sync tasks
final class SyncPauseReportingTests: XCTestCase {
  private var tasksDataManager: TasksDataManager!
  private var repository: SyncQueueRepository!
  private var service: SyncQueueService!

  override func setUpWithError() throws {
    let schema = Schema(versionedSchema: SchemaV3.self)
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: config)
    tasksDataManager = TasksDataManager(container: container)
    repository = SyncQueueRepository(tasksDataManager: tasksDataManager)
    service = SyncQueueService(maxConcurrentTasks: 1)
    service.taskContainer = repository
    service.tasksDataManager = tasksDataManager
  }

  override func tearDown() {
    service = nil
    repository = nil
    tasksDataManager = nil
    super.tearDown()
  }

  private func pausedTask(
    id: String = "task-1",
    sentryEventId: String? = nil
  ) -> QueuedSyncTask {
    QueuedSyncTask(
      id: id,
      queueKey: TaskQueueKey.sync,
      jobType: .shallowDelete,
      parameters: [:],
      uuid: "item-uuid",
      relativePath: "Private Folder/Secret Book.mp3",
      pause: TaskPause(
        scope: .lane,
        errorCode: "item_not_found",
        message: "Item not found: \"Private Folder/Secret Book.mp3\"",
        httpStatus: 404,
        pausedAt: Date(timeIntervalSince1970: 0),
        sentryEventId: sentryEventId
      )
    )
  }

  // MARK: - Sentry

  /// Minimal payload: the failure's identity only — never the server message or the path,
  /// which embed file names
  @MainActor
  func testReporter_sendsTheMinimalEvent_andRecordsItsId() async throws {
    try await repository.storeTask(parameters: [
      "id": "task-1",
      "uuid": "item-uuid",
      "jobType": SyncJobType.shallowDelete.rawValue,
      "queueKey": TaskQueueKey.sync,
      "relativePath": "Private Folder/Secret Book.mp3",
    ])
    await repository.park(
      taskId: "task-1",
      pause: TaskPause(scope: .lane, errorCode: "item_not_found", message: "m", httpStatus: 404, pausedAt: Date())
    )

    var captured = [Event]()
    let eventId = SentryId()
    let reporter = SyncPauseReporter(syncQueueService: service) { event in
      captured.append(event)
      return eventId
    }

    reporter.report(pausedTask())

    XCTAssertEqual(captured.count, 1)
    let event = try XCTUnwrap(captured.first)
    XCTAssertEqual(event.level, .warning)
    XCTAssertEqual(event.fingerprint, ["sync-paused", "shallowDelete", "item_not_found"])
    XCTAssertEqual(event.tags?["sync.job_type"], "shallowDelete")
    XCTAssertEqual(event.tags?["sync.error_code"], "item_not_found")
    XCTAssertEqual(event.tags?["sync.http_status"], "404")
    XCTAssertEqual(event.tags?["sync.lane"], TaskQueueKey.sync)
    XCTAssertEqual(event.tags?["sync.pause_scope"], "lane")
    XCTAssertEqual(event.extra?["item_uuid"] as? String, "item-uuid")

    let payload = [
      event.message?.formatted ?? "",
      "\(event.tags ?? [:])",
      "\(event.extra ?? [:])",
    ].joined()
    XCTAssertFalse(payload.contains("Secret Book"), "file names must never reach Sentry")

    let deadline = Date().addingTimeInterval(2)
    var stored: String?
    while Date() < deadline {
      stored = await repository.getAllTasks().first?.pause?.sentryEventId
      if stored != nil { break }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertEqual(stored, eventId.sentryIdString)
  }

  /// Once per task: already reported (stored id), or reported earlier this session before
  /// the id was written back
  @MainActor
  func testReporter_reportsEachTaskOnce() {
    var captures = 0
    let reporter = SyncPauseReporter(syncQueueService: service) { _ in
      captures += 1
      return SentryId()
    }

    reporter.report(pausedTask(id: "reported", sentryEventId: "evt-1"))
    XCTAssertEqual(captures, 0)

    reporter.report(pausedTask(id: "new"))
    reporter.report(pausedTask(id: "new"))
    XCTAssertEqual(captures, 1)
  }

  /// Crash reports off: nothing was sent, so the task must stay unreported
  @MainActor
  func testReporter_withSentryDisabled_leavesTheTaskUnreported() async throws {
    try await repository.storeTask(parameters: [
      "id": "task-1",
      "uuid": "item-uuid",
      "jobType": SyncJobType.shallowDelete.rawValue,
      "queueKey": TaskQueueKey.sync,
      "relativePath": "a.mp3",
    ])
    await repository.park(
      taskId: "task-1",
      pause: TaskPause(scope: .lane, errorCode: "item_not_found", message: "m", httpStatus: 404, pausedAt: Date())
    )
    let reporter = SyncPauseReporter(syncQueueService: service) { _ in SentryId.empty }

    reporter.report(pausedTask())
    try await Task.sleep(for: .milliseconds(300))

    let stored = await repository.getAllTasks().first?.pause
    XCTAssertNotNil(stored)
    XCTAssertNil(stored?.sentryEventId)
  }

  /// Turning crash reports back on mid-session: the next park of the same task reports
  @MainActor
  func testReporter_retriesATaskWhoseReportWasNotSent() {
    var sentryEnabled = false
    var captures = 0
    let reporter = SyncPauseReporter(syncQueueService: service) { _ in
      captures += 1
      return sentryEnabled ? SentryId() : SentryId.empty
    }

    reporter.report(pausedTask(id: "later"))
    sentryEnabled = true
    reporter.report(pausedTask(id: "later"))
    reporter.report(pausedTask(id: "later"))

    XCTAssertEqual(captures, 2, "unsent once, then sent once")
  }

  @MainActor
  func testReporter_observesThePausedNotification() {
    var captures = 0
    let reporter = SyncPauseReporter(syncQueueService: service) { _ in
      captures += 1
      return SentryId()
    }

    NotificationCenter.default.post(name: .syncTaskPaused, object: pausedTask(id: "notified"))

    XCTAssertEqual(captures, 1)
    withExtendedLifetime(reporter) {}
  }

  // MARK: - Report attachment

  func testReport_listsThePausedTask_theQueue_andTheLocalLibraryWithUuids() {
    let pending = QueuedSyncTask(
      id: "task-2",
      queueKey: TaskQueueKey.uploadFile,
      jobType: .uploadFile,
      parameters: [:],
      uuid: "upload-uuid",
      relativePath: "Book 2.mp3"
    )
    let report = SyncPauseReport(
      pausedTask: pausedTask(sentryEventId: "evt-9"),
      queuedTasks: [pausedTask(sentryEventId: "evt-9"), pending],
      library: [("Private Folder", "folder-uuid"), ("Private Folder/Secret Book.mp3", "item-uuid")],
      appVersion: "6.0.0-100c",
      systemVersion: "iOS 26.0",
      deviceName: "iPhone"
    )

    let text = report.text
    XCTAssertTrue(text.contains("App: 6.0.0-100c"))
    XCTAssertTrue(text.contains("Status: paused (lane) · item_not_found 404"))
    XCTAssertTrue(text.contains("Message: Item not found"))
    XCTAssertTrue(text.contains("Sentry event: evt-9"))
    XCTAssertTrue(text.contains("-- Queued tasks (2) --"))
    XCTAssertTrue(text.contains("uploadFile · lane uploadFile\n  Status: pending"))
    XCTAssertTrue(text.contains("Secret Book.mp3 (item-uuid)"))
    XCTAssertTrue(text.contains("Private Folder (folder-uuid)"))
    XCTAssertTrue(report.subject.contains("item_not_found"))
  }

  /// Local state only: whether each item's file is on this device, with its uuid when given
  func testLibraryTree_showsLocalFilesAndUuids() {
    let tree = LibraryTreeRepresentation.render(entries: [("Book.mp3", "book-uuid"), ("Other.mp3", nil)])
    XCTAssertEqual(tree, "Library\n.\n|-- [𐄂] Book.mp3 (book-uuid)\n`-- [𐄂] Other.mp3\n")
  }

  func testReport_writesANamedFile() throws {
    let report = SyncPauseReport(
      pausedTask: pausedTask(),
      queuedTasks: [],
      library: [],
      appVersion: "1",
      systemVersion: "iOS",
      deviceName: "iPhone"
    )
    let url = try report.writeToTemporaryFile()
    defer { try? FileManager.default.removeItem(at: url) }
    XCTAssertEqual(url.lastPathComponent, SyncPauseReport.fileName)
    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), report.text)
  }
}
