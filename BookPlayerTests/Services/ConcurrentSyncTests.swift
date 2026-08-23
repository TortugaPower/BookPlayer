//
//  ConcurrentSyncTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftData
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// First dedicated coverage for the unified concurrent-sync engine: task persistence
/// round-trips (notably `hostId`, whose omission silently discarded every persisted progress
/// push), queue ordering, the per-tier access policy, and the operation state machine.
final class ConcurrentSyncTests: XCTestCase {
  private var tasksDataManager: TasksDataManager!
  private var repository: ConcurrentTasksRepository!

  override func setUpWithError() throws {
    let schema = Schema([
      UploadTaskModel.self,
      UpdateTaskModel.self,
      MoveTaskModel.self,
      DeleteTaskModel.self,
      DeleteBookmarkTaskModel.self,
      SetBookmarkTaskModel.self,
      RenameFolderTaskModel.self,
      ArtworkUploadTaskModel.self,
      MatchUuidsTaskModel.self,
      UploadExternalResourceTaskModel.self,
      ExternalResourceToDownloadTaskModel.self,
      DeleteExternalResourceTaskModel.self,
      ConcurrentTasksContainer.self,
      ConcurrentTaskReferenceModel.self,
      ExternalUpdateTaskModel.self,
      ConcurrentUploadTaskModel.self,
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: config)
    tasksDataManager = TasksDataManager(container: container)
    repository = ConcurrentTasksRepository(tasksDataManager: tasksDataManager)
  }

  override func tearDown() {
    repository = nil
    tasksDataManager = nil
    super.tearDown()
  }

  private func externalUpdateParams(
    id: String = UUID().uuidString,
    providerId: String = "item-1",
    hostId: String? = "82f33a82610b4869879615f9c6cb1ece"
  ) -> [String: Any] {
    var params: [String: Any] = [
      "id": id,
      "jobType": SyncJobType.externalUpdate.rawValue,
      "queueKey": "jellyfin",
      "providerName": "jellyfin",
      "providerId": providerId,
      "currentTime": 123.5,
      "percentCompleted": 42.0,
    ]
    if let hostId {
      params["hostId"] = hostId
    }
    return params
  }

  // MARK: - Persistence round-trips

  /// The whole progress-push path routes by stable host: dropping `hostId` between store and
  /// reload makes the operation resolve no connection and (correctly) discard EVERY push.
  func testExternalUpdateTask_roundTripsHostId() async throws {
    try await repository.storeTask(parameters: externalUpdateParams())

    // getNextTask is the accessor the WORKER uses to reload persisted tasks — the payload
    // join happens there (getAllTasks is a display-level list with empty parameters).
    let task = await repository.getNextTask(for: "jellyfin")
    let params = try XCTUnwrap(task?.parameters)
    XCTAssertEqual(params["hostId"] as? String, "82f33a82610b4869879615f9c6cb1ece")
    XCTAssertEqual(params["providerId"] as? String, "item-1")
    XCTAssertEqual(params["providerName"] as? String, "jellyfin")
    XCTAssertEqual(params["currentTime"] as? Double, 123.5)
    XCTAssertEqual(params["percentCompleted"] as? Double, 42.0)
  }

  func testExternalUpdateTask_withoutHostId_roundTripsAsAbsent() async throws {
    try await repository.storeTask(parameters: externalUpdateParams(hostId: nil))

    let task = await repository.getNextTask(for: "jellyfin")
    XCTAssertNotNil(task)
    XCTAssertNil(task?.parameters["hostId"])
  }

  func testTasks_preserveInsertionOrder() async throws {
    try await repository.storeTask(parameters: externalUpdateParams(id: "task-a", providerId: "a"))
    try await repository.storeTask(parameters: externalUpdateParams(id: "task-b", providerId: "b"))
    try await repository.storeTask(parameters: externalUpdateParams(id: "task-c", providerId: "c"))

    // FIFO through the worker's own next+pop cycle.
    var seen = [String]()
    while let task = await repository.getNextTask(for: "jellyfin") {
      seen.append(task.parameters["providerId"] as? String ?? "?")
      await repository.pop(task)
    }
    XCTAssertEqual(seen, ["a", "b", "c"])
  }

  func testGetOrderedTasks_putsActiveTasksFirst() async throws {
    try await repository.storeTask(parameters: externalUpdateParams(id: "task-a", providerId: "a"))
    try await repository.storeTask(parameters: externalUpdateParams(id: "task-b", providerId: "b"))

    let ordered = await repository.getOrderedTasks(activeTaskIDs: ["task-b"])
    XCTAssertEqual(ordered.first?.id, "task-b")
    XCTAssertEqual(ordered.count, 2)
  }

  func testPop_removesTheTask() async throws {
    try await repository.storeTask(parameters: externalUpdateParams(id: "task-a"))
    let tasks = await repository.getAllTasks()
    let task = try XCTUnwrap(tasks.first)

    await repository.pop(task)

    let remaining = await repository.getAllTasks()
    XCTAssertTrue(remaining.isEmpty)
  }

  // MARK: - Access policy (per-tier gating)

  /// `externalUpdate` targets the USER'S OWN media server, so it stays available on every
  /// tier (Android parity); `uploadFile` (S3) is PRO-only.
  func testAccessPolicy_perTier() {
    let service = ConcurrenceService(maxConcurrentTasks: 1)

    service.updateConcurrentService(.pro)
    XCTAssertEqual(service.accessPolicy[.externalUpdate], true)
    XCTAssertEqual(service.accessPolicy[.uploadFile], true)

    service.updateConcurrentService(.lite)
    XCTAssertEqual(service.accessPolicy[.externalUpdate], true)
    XCTAssertEqual(service.accessPolicy[.uploadFile], false)

    service.updateConcurrentService(.free)
    XCTAssertEqual(service.accessPolicy[.externalUpdate], true)
    XCTAssertEqual(service.accessPolicy[.uploadFile], false)

    service.updateConcurrentService(.plus)
    XCTAssertEqual(service.accessPolicy[.externalUpdate], true)
    XCTAssertEqual(service.accessPolicy[.uploadFile], false)
  }

  func testScheduleMetadataUpdate_gatedByPolicy() async throws {
    let service = ConcurrenceService(maxConcurrentTasks: 1)
    service.taskContainer = repository

    // Denied: nothing is persisted.
    service.accessPolicy = [.externalUpdate: false]
    service.scheduleMetadataUpdate(params: ["providerName": "jellyfin", "providerId": "item-1"])
    try await Task.sleep(for: .milliseconds(300))
    var tasks = await repository.getAllTasks()
    XCTAssertTrue(tasks.isEmpty)

    // Allowed: the task lands with the right jobType and provider queue.
    service.accessPolicy = [.externalUpdate: true]
    service.scheduleMetadataUpdate(params: [
      "providerName": "jellyfin",
      "providerId": "item-1",
      "hostId": "guid-1",
    ])
    try await waitForTaskCount(1)
    let stored = await repository.getNextTask(for: "jellyfin")
    XCTAssertEqual(stored?.jobType, .externalUpdate)
    XCTAssertEqual(stored?.queueKey, "jellyfin")
    XCTAssertEqual(stored?.parameters["hostId"] as? String, "guid-1")
  }

  func testScheduleFileUpload_gatedByPolicy() async throws {
    let service = ConcurrenceService(maxConcurrentTasks: 1)
    service.taskContainer = repository

    service.accessPolicy = [.uploadFile: false]
    service.scheduleFileUpload(params: ["filePath": "/tmp/a", "remotePath": "https://s3/a", "uuid": "u1"])
    try await Task.sleep(for: .milliseconds(300))
    let denied = await repository.getAllTasks()
    XCTAssertTrue(denied.isEmpty)

    service.accessPolicy = [.uploadFile: true]
    service.scheduleFileUpload(params: ["filePath": "/tmp/a", "remotePath": "https://s3/a", "uuid": "u1"])
    try await waitForTaskCount(1)
    let allowed = await repository.getNextTask(for: TaskQueueKey.uploadFile)
    XCTAssertEqual(allowed?.jobType, .uploadFile)
    XCTAssertEqual(allowed?.parameters["filePath"] as? String, "/tmp/a")
  }

  // MARK: - Operation state machine

  func testAsyncOperation_finishFlipsStateFromAnotherThread() {
    let operation = AsyncOperation()
    XCTAssertTrue(operation.isReady)
    XCTAssertFalse(operation.isExecuting)

    operation.start()
    XCTAssertTrue(operation.isExecuting)

    let finished = expectation(description: "finished")
    DispatchQueue.global().async {
      operation.finish()
      finished.fulfill()
    }
    wait(for: [finished], timeout: 2)
    XCTAssertTrue(operation.isFinished)
    XCTAssertFalse(operation.isExecuting)
  }

  func testAsyncOperation_cancelledBeforeStartFinishesImmediately() {
    let operation = AsyncOperation()
    operation.cancel()
    operation.start()
    XCTAssertTrue(operation.isFinished)
  }

  /// A permanently-missing source file must CONSUME the upload (didSucceed) instead of failing:
  /// the queue retries failures forever on one serial key, so a poison task would hot-loop and
  /// block every other upload behind it.
  func testFileUploadOperation_missingSourceFile_isConsumedNotRetried() {
    let operation = FileUploadOperation(
      fileURL: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).m4b"),
      remoteURL: URL(string: "https://example.com/upload")!,
      uuid: "task-uuid"
    )

    operation.start()

    let done = expectation(description: "operation finished")
    let observer = operation.observe(\.isFinished, options: [.initial, .new]) { op, _ in
      if op.isFinished { done.fulfill() }
    }
    wait(for: [done], timeout: 5)
    observer.invalidate()

    XCTAssertTrue(operation.didSucceed, "a missing source file is permanent — the task must be consumed")
  }

  // MARK: - Helpers

  private func waitForTaskCount(_ count: Int, timeout: TimeInterval = 3) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      let tasks = await repository.getAllTasks()
      if tasks.count >= count { return }
      try await Task.sleep(for: .milliseconds(50))
    }
    XCTFail("timed out waiting for \(count) task(s)")
  }
}
