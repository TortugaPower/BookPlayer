//
//  SyncTasksStorageTests.swift
//  BookPlayerTests
//
//  Created by Claude on 2026-04-21.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftData
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

final class SyncTasksStorageTests: XCTestCase {
  private var tasksDataManager: TasksDataManager!
  private var storage: SyncTasksStorage!

  override func setUpWithError() throws {
    let schema = Schema([
      SyncTasksContainer.self,
      SyncTaskReferenceModel.self,
      UploadTaskModel.self,
      UpdateTaskModel.self,
      MoveTaskModel.self,
      DeleteTaskModel.self,
      DeleteBookmarkTaskModel.self,
      SetBookmarkTaskModel.self,
      RenameFolderTaskModel.self,
      ArtworkUploadTaskModel.self,
      MatchUuidsTaskModel.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: config)
    tasksDataManager = TasksDataManager(container: container)
    storage = try SyncTasksStorage(tasksDataManager: tasksDataManager)
  }

  override func tearDown() {
    storage = nil
    tasksDataManager = nil
    super.tearDown()
  }

  /// Progress lookup must key on `uuid`, so a progress dictionary indexed by uuid
  /// surfaces correctly on the returned SyncTaskReference.
  func testGetAllTasks_progressKeyedByUuid_returnsProgressForTask() async throws {
    let uuid = "item-uuid-1"
    let relativePath = "Folder/Book.mp3"
    try await appendUploadTask(uuid: uuid, relativePath: relativePath)

    let references = await storage.getAllTasks(progress: [uuid: 0.42])

    XCTAssertEqual(references.count, 1)
    let reference = try XCTUnwrap(references.first)
    XCTAssertEqual(reference.uuid, uuid)
    XCTAssertEqual(reference.progress, 0.42, accuracy: 0.0001)
  }

  /// Regression guard: with a real uuid, a progress dict keyed by relativePath must NOT resolve.
  func testGetAllTasks_progressKeyedByRelativePath_returnsZero() async throws {
    let uuid = "item-uuid-2"
    let relativePath = "Folder/Other.mp3"
    try await appendUploadTask(uuid: uuid, relativePath: relativePath)

    let references = await storage.getAllTasks(progress: [relativePath: 0.75])

    XCTAssertEqual(references.count, 1)
    let reference = try XCTUnwrap(references.first)
    XCTAssertEqual(reference.progress, 0.0)
  }

  /// Legacy-migrated task references share the same placeholder uuid; the progress key
  /// must fall back to `relativePath` so sibling rows don't collide on the same key.
  func testGetAllTasks_legacyPlaceholderUuid_fallsBackToRelativePath() async throws {
    let relativePath = "Folder/Legacy.mp3"
    try await appendUploadTask(uuid: Constants.legacyUuidPlaceholder, relativePath: relativePath)

    let references = await storage.getAllTasks(progress: [relativePath: 0.6])

    XCTAssertEqual(references.count, 1)
    let reference = try XCTUnwrap(references.first)
    XCTAssertEqual(reference.progress, 0.6, accuracy: 0.0001)
  }

  /// Same fallback applies to the local placeholder used as the schema default.
  func testGetAllTasks_localPlaceholderUuid_fallsBackToRelativePath() async throws {
    let relativePath = "Folder/Local.mp3"
    try await appendUploadTask(uuid: Constants.uuidPlaceholder, relativePath: relativePath)

    let references = await storage.getAllTasks(progress: [relativePath: 0.33])

    XCTAssertEqual(references.count, 1)
    let reference = try XCTUnwrap(references.first)
    XCTAssertEqual(reference.progress, 0.33, accuracy: 0.0001)
  }

  /// `matchUuid` conflicts must rewrite both the task reference and the underlying task
  /// model from the old (local) uuid to the new (server-assigned) uuid.
  func testApplyMatchUuidConflicts_rewritesRefAndTaskUuid() async throws {
    let oldUuid = "old-uuid"
    let newUuid = "new-uuid"
    let relativePath = "Folder/Swap.mp3"
    try await appendUploadTask(uuid: oldUuid, relativePath: relativePath)

    try await storage.applyMatchUuidConflicts([ItemConflict(key: oldUuid, uuid: newUuid)])

    let refs = await storage.getAllTasks(progress: [:])
    XCTAssertEqual(refs.count, 1)
    XCTAssertEqual(refs.first?.uuid, newUuid)

    let tasks = await storage.getAllTasksWithParams()
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.uuid, newUuid)
  }

  /// Conflicts whose `key` doesn't match any stored reference should be a no-op.
  func testApplyMatchUuidConflicts_noMatch_leavesStoreUnchanged() async throws {
    let uuid = "existing-uuid"
    try await appendUploadTask(uuid: uuid, relativePath: "Folder/Other.mp3")

    try await storage.applyMatchUuidConflicts([ItemConflict(key: "ghost-uuid", uuid: "never")])

    let refs = await storage.getAllTasks(progress: [:])
    XCTAssertEqual(refs.first?.uuid, uuid)
  }

  /// A second matchUuid schedule should merge into the existing task rather than queue a second one.
  /// Note: the dedup skips coalescing when the existing matchUuid sits at the head of the queue
  /// (presumed in flight), so this test occupies the head with an unrelated upload task first.
  func testAppendMatchUuidTask_existingTask_mergesPreferringExistingValues() async throws {
    try await appendUploadTask(uuid: "upload-uuid", relativePath: "folder/Head.mp3")
    try await appendMatchUuidTask(uuids: ["folder/A.mp3": "uuid-A", "folder/B.mp3": "uuid-B"])
    // Second call reuses one existing key with a different uuid (should be kept as-is)
    // and introduces a new key (should be added).
    try await appendMatchUuidTask(uuids: ["folder/A.mp3": "uuid-A-prime", "folder/C.mp3": "uuid-C"])

    let refs = await storage.getAllTasks(progress: [:])
    XCTAssertEqual(refs.filter { $0.jobType == .matchUuid }.count, 1)

    let tasks = await storage.getAllTasksWithParams()
    let matchTask = try XCTUnwrap(tasks.first(where: { $0.jobType == .matchUuid }))
    let mergedUuids = try XCTUnwrap(matchTask.parameters["uuids"] as? [String: String])
    XCTAssertEqual(mergedUuids["folder/A.mp3"], "uuid-A")           // existing preserved
    XCTAssertEqual(mergedUuids["folder/B.mp3"], "uuid-B")           // existing preserved
    XCTAssertEqual(mergedUuids["folder/C.mp3"], "uuid-C")           // new added
    XCTAssertEqual(mergedUuids.count, 3)
  }

  /// With no prior matchUuid task, the first call should create one normally.
  func testAppendMatchUuidTask_noExisting_createsNewTask() async throws {
    try await appendMatchUuidTask(uuids: ["folder/A.mp3": "uuid-A"])

    let refs = await storage.getAllTasks(progress: [:])
    XCTAssertEqual(refs.count, 1)
    XCTAssertEqual(refs.first?.jobType, .matchUuid)
  }

  /// When the existing matchUuid is in flight (head of the queue), a new schedule call
  /// must NOT mutate it — a second matchUuid task gets queued instead. Further calls
  /// then coalesce into the second task, leaving the in-flight one untouched.
  func testAppendMatchUuidTask_firstInFlight_queuesSecondAndMergesIntoIt() async throws {
    try await appendMatchUuidTask(uuids: ["folder/A.mp3": "uuid-A"])

    // Simulate the first task being in flight — the scheduler calls getNextTask()
    // to hand the snapshot to the operation queue; the task stays in the store.
    let inFlight = try await storage.getNextTask()
    XCTAssertEqual(inFlight?.jobType, .matchUuid)

    // A second schedule must bypass the in-flight task and create a fresh one.
    try await appendMatchUuidTask(uuids: ["folder/B.mp3": "uuid-B"])

    let refsAfterSecond = await storage.getAllTasks(progress: [:])
    let matchRefsAfterSecond = refsAfterSecond.filter { $0.jobType == .matchUuid }
    XCTAssertEqual(matchRefsAfterSecond.count, 2)

    // A third schedule must merge into the second (non-in-flight) task,
    // leaving the in-flight task's dict unchanged.
    try await appendMatchUuidTask(uuids: ["folder/C.mp3": "uuid-C"])

    let tasksAfterThird = await storage.getAllTasksWithParams()
    let matchTasks = tasksAfterThird.filter { $0.jobType == .matchUuid }
    XCTAssertEqual(matchTasks.count, 2)

    let inFlightTask = try XCTUnwrap(matchTasks.first)
    let inFlightUuids = try XCTUnwrap(inFlightTask.parameters["uuids"] as? [String: String])
    XCTAssertEqual(inFlightUuids, ["folder/A.mp3": "uuid-A"])

    let queuedTask = try XCTUnwrap(matchTasks.last)
    let queuedUuids = try XCTUnwrap(queuedTask.parameters["uuids"] as? [String: String])
    XCTAssertEqual(queuedUuids, ["folder/B.mp3": "uuid-B", "folder/C.mp3": "uuid-C"])
  }

  private func appendMatchUuidTask(uuids: [String: String]) async throws {
    let parameters: [String: Any] = [
      "id": UUID().uuidString,
      "jobType": SyncJobType.matchUuid.rawValue,
      "relativePath": "",
      "uuid": "",
      "uuids": uuids
    ]
    try await storage.appendTask(parameters: parameters)
  }

  private func appendUploadTask(uuid: String, relativePath: String) async throws {
    let parameters: [String: Any] = [
      "id": UUID().uuidString,
      "uuid": uuid,
      "relativePath": relativePath,
      "originalFileName": "Book.mp3",
      "title": "Book",
      "details": "Author",
      "currentTime": 0.0,
      "duration": 100.0,
      "percentCompleted": 0.0,
      "isFinished": false,
      "orderRank": 0,
      "type": SimpleItemType.book.rawValue,
      "jobType": SyncJobType.upload.rawValue
    ]
    try await storage.appendTask(parameters: parameters)
  }
}
