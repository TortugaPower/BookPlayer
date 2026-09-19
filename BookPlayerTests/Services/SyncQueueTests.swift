//
//  SyncQueueTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation
import SwiftData
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// First dedicated coverage for the sync-queue engine: task persistence
/// round-trips (notably `hostId`, whose omission silently discarded every persisted progress
/// push), queue ordering, the per-tier access policy, and the operation state machine.
final class SyncQueueTests: XCTestCase {
  private var tasksDataManager: TasksDataManager!
  private var repository: SyncQueueRepository!

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
      SyncQueueContainer.self,
      QueuedTaskReferenceModel.self,
      ExternalUpdateTaskModel.self,
      UploadFileTaskModel.self,
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: config)
    tasksDataManager = TasksDataManager(container: container)
    repository = SyncQueueRepository(tasksDataManager: tasksDataManager)
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
    let service = SyncQueueService(maxConcurrentTasks: 1)

    service.updateAccessPolicy(.pro)
    XCTAssertEqual(service.accessPolicy[.externalUpdate], true)
    XCTAssertEqual(service.accessPolicy[.uploadFile], true)

    service.updateAccessPolicy(.lite)
    XCTAssertEqual(service.accessPolicy[.externalUpdate], true)
    XCTAssertEqual(service.accessPolicy[.uploadFile], false)

    service.updateAccessPolicy(.free)
    XCTAssertEqual(service.accessPolicy[.externalUpdate], true)
    XCTAssertEqual(service.accessPolicy[.uploadFile], false)

    service.updateAccessPolicy(.plus)
    XCTAssertEqual(service.accessPolicy[.externalUpdate], true)
    XCTAssertEqual(service.accessPolicy[.uploadFile], false)
  }

  func testScheduleMetadataUpdate_gatedByPolicy() async throws {
    let service = SyncQueueService(maxConcurrentTasks: 1)
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
    let service = SyncQueueService(maxConcurrentTasks: 1)
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

// MARK: - Policy ownership (self-refresh on account updates)

extension SyncQueueTests {
  /// The mid-session-upgrade pin: the service re-derives its per-job policy from
  /// .accountUpdate on its own — no coordinator wiring. Before this, an upgrade left
  /// file uploads gated off until the next app start unless every platform remembered
  /// to forward the new level manually.
  @MainActor
  func testAccessPolicyRefreshesOnAccountUpdate() {
    let service = SyncQueueService(maxConcurrentTasks: 1)
    var level = AccessLevel.free
    service.getAccessLevel = { level }
    service.bindAccountObserver()
    service.updateAccessPolicy(level)
    XCTAssertEqual(service.accessPolicy[.uploadFile], false)

    level = .pro
    NotificationCenter.default.post(name: .accountUpdate, object: nil)

    // The sink hops through DispatchQueue.main; one enqueued block after the post
    // is guaranteed to run after the delivery.
    let refreshed = expectation(description: "policy refreshed")
    DispatchQueue.main.async { refreshed.fulfill() }
    wait(for: [refreshed], timeout: 1)

    XCTAssertEqual(service.accessPolicy[.uploadFile], true, "mid-session upgrade must reach the policy")
    XCTAssertEqual(service.accessPolicy[.externalUpdate], true)
  }
}

// MARK: - Queue counts (engine-owned)

extension SyncQueueTests {
  private func syncUpdateParams(id: String, relativePath: String) -> [String: Any] {
    [
      "id": id,
      "uuid": UUID().uuidString,
      "jobType": SyncJobType.update.rawValue,
      "queueKey": TaskQueueKey.sync,
      "relativePath": relativePath,
    ]
  }

  private func uploadFileParams(id: String) -> [String: Any] {
    [
      "id": id,
      "jobType": SyncJobType.uploadFile.rawValue,
      "queueKey": TaskQueueKey.uploadFile,
      "filePath": "/tmp/\(id).m4b",
      "remotePath": "https://s3/\(id)",
      "uuid": id,
    ]
  }

  /// First snapshot satisfying `predicate`. The publisher replays its latest value on
  /// subscribe, so a state reached BEFORE subscribing still resolves.
  private func awaitCounts(
    from publisher: AnyPublisher<QueueCounts, Never>,
    timeout: TimeInterval = 3,
    where predicate: @escaping (QueueCounts) -> Bool
  ) async throws -> QueueCounts {
    let matched = expectation(description: "queue counts matched")
    var result: QueueCounts?
    let subscription = publisher.sink { counts in
      guard result == nil, predicate(counts) else { return }
      result = counts
      matched.fulfill()
    }
    await fulfillment(of: [matched], timeout: timeout)
    subscription.cancel()
    return try XCTUnwrap(result)
  }

  func testQueueCounts_totalAndPerLane() {
    let counts = QueueCounts(byQueueKey: [TaskQueueKey.sync: 2, "jellyfin": 3])
    XCTAssertEqual(counts.total, 5)
    XCTAssertEqual(counts.count(in: "jellyfin"), 3)
    XCTAssertEqual(counts.count(in: TaskQueueKey.uploadFile), 0, "an absent lane reads as zero")
    XCTAssertEqual(QueueCounts().total, 0)
  }

  /// The engine owns every lane, so ONE publisher carries all counts: the Profile row sums
  /// it, the sectioned screen reads one lane at a time.
  func testQueueCounts_trackEveryLane() async throws {
    try await repository.storeTask(parameters: externalUpdateParams(id: "j1", providerId: "a"))
    try await repository.storeTask(parameters: externalUpdateParams(id: "j2", providerId: "b"))
    try await repository.storeTask(parameters: uploadFileParams(id: "u1"))
    try await repository.storeTask(parameters: syncUpdateParams(id: "s1", relativePath: "book.m4b"))

    let counts = try await awaitCounts(from: tasksDataManager.observeQueueCounts()) { $0.total == 4 }
    XCTAssertEqual(counts.count(in: "jellyfin"), 2)
    XCTAssertEqual(counts.count(in: TaskQueueKey.uploadFile), 1)
    XCTAssertEqual(counts.count(in: TaskQueueKey.sync), 1)
    XCTAssertEqual(counts.byQueueKey.count, 3)
  }

  func testQueueCounts_drainedLaneLeavesTheSnapshot() async throws {
    try await repository.storeTask(parameters: externalUpdateParams(id: "j1"))
    _ = try await awaitCounts(from: tasksDataManager.observeQueueCounts()) { $0.total == 1 }
    let next = await repository.getNextTask(for: "jellyfin")
    let task = try XCTUnwrap(next)

    await repository.pop(task)

    let counts = try await awaitCounts(from: tasksDataManager.observeQueueCounts()) { $0.total == 0 }
    XCTAssertEqual(counts.count(in: "jellyfin"), 0)
    XCTAssertNil(counts.byQueueKey["jellyfin"])
  }

  /// Pins the list-refresh gate: `SyncService.canSyncListContents` reads the sync lane only
  /// (`getTasksCount(in:)`), so a heavy S3 upload or a provider push never blocks a refresh.
  func testSyncLaneCount_ignoresUploadsAndProviderPushes() async throws {
    try await repository.storeTask(parameters: uploadFileParams(id: "u1"))
    try await repository.storeTask(parameters: externalUpdateParams(id: "j1"))

    let syncLaneCount = await repository.getTasksCount(in: TaskQueueKey.sync)
    XCTAssertEqual(syncLaneCount, 0)
    let counts = try await awaitCounts(from: tasksDataManager.observeQueueCounts()) { $0.total == 2 }
    XCTAssertEqual(counts.count(in: TaskQueueKey.sync), 0)
  }

  /// The engine forwards the store owner's publisher — no second bookkeeping anywhere.
  func testEngine_observeQueueCounts_forwardsTheStoreOwner() async throws {
    let service = SyncQueueService(maxConcurrentTasks: 1)
    service.taskContainer = repository
    service.tasksDataManager = tasksDataManager
    try await repository.storeTask(parameters: externalUpdateParams(id: "j1"))

    let counts = try await awaitCounts(from: service.observeQueueCounts()) { $0.total == 1 }
    XCTAssertEqual(counts.count(in: "jellyfin"), 1)
  }

  /// Background refresh waits on this: only the named lane matters, whatever the others hold.
  func testLaneDrained_followsOnlyTheNamedLane() {
    let subject = CurrentValueSubject<QueueCounts, Never>(
      QueueCounts(byQueueKey: [TaskQueueKey.sync: 1, TaskQueueKey.uploadFile: 3])
    )
    var seen = [Bool]()
    let subscription = subject.laneDrained(TaskQueueKey.sync).sink { seen.append($0) }
    defer { subscription.cancel() }

    subject.send(QueueCounts(byQueueKey: [TaskQueueKey.uploadFile: 3]))
    subject.send(QueueCounts(byQueueKey: [TaskQueueKey.uploadFile: 3, "jellyfin": 2]))

    XCTAssertEqual(seen, [false, true, true])
  }
}
