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

  /// A denied upload never reads the temp hard link scheduled for it, so it's removed.
  func testScheduleFileUpload_denied_removesTheTempHardLink() async throws {
    let service = SyncQueueService(maxConcurrentTasks: 1)
    service.taskContainer = repository
    service.accessPolicy = [.uploadFile: false]
    let link = FileManager.default.temporaryDirectory.appendingPathComponent("denied-\(UUID().uuidString).mp3")
    try Data("x".utf8).write(to: link)

    service.scheduleFileUpload(params: ["filePath": link.absoluteString, "uuid": "u1"])

    XCTAssertFalse(FileManager.default.fileExists(atPath: link.path))
    let tasks = await repository.getAllTasks()
    XCTAssertTrue(tasks.isEmpty)
  }

  func testScheduleFileUpload_gatedByPolicy() async throws {
    let service = SyncQueueService(maxConcurrentTasks: 1)
    service.taskContainer = repository

    service.accessPolicy = [.uploadFile: false]
    service.scheduleFileUpload(params: ["filePath": "/tmp/a", "uuid": "u1"])
    try await Task.sleep(for: .milliseconds(300))
    let denied = await repository.getAllTasks()
    XCTAssertTrue(denied.isEmpty)

    service.accessPolicy = [.uploadFile: true]
    service.scheduleFileUpload(params: ["filePath": "/tmp/a", "uuid": "u1"])
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

// MARK: - Server-lane gate (sync off holds the BookPlayer-server lanes)

extension SyncQueueTests {
  /// Engine wired to the in-memory repository. The upload's source file doesn't exist, so
  /// once it runs the operation consumes it without any network: the pop is the signal.
  private func makeGatedEngine() -> SyncQueueService {
    let service = SyncQueueService(maxConcurrentTasks: 1)
    service.taskContainer = repository
    service.tasksDataManager = tasksDataManager
    service.accessPolicy = [.uploadFile: true, .externalUpdate: true]
    service.networkClient = NetworkClientMock(mockedResponse: Empty())
    return service
  }

  private func waitForEmptyQueue(timeout: TimeInterval = 3) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if await repository.getAllTasks().isEmpty { return }
      try await Task.sleep(for: .milliseconds(50))
    }
    XCTFail("timed out waiting for the queue to drain")
  }

  /// The lapsed-subscriber retry storm: a persisted server-lane task must not run while
  /// sync is off, must survive (not be cleared), and must run once sync turns on.
  func testServerLanes_holdTasksWhileGated_andRunThemOnEnable() async throws {
    let service = makeGatedEngine()
    var params = uploadFileParams(id: "gated-1")
    params["filePath"] = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).m4b").absoluteString
    try await repository.storeTask(parameters: params)

    XCTAssertFalse(service.serverLanesEnabled)
    service.wakeUpWorkers()
    try await Task.sleep(for: .milliseconds(400))
    let held = await repository.getAllTasks()
    XCTAssertEqual(held.count, 1, "a gated lane must neither run nor drop its tasks")

    service.setServerLanesEnabled(true)
    try await waitForEmptyQueue()
  }

  /// A lapse while a worker is mid-lane: the running task finishes, the next one is held
  /// (not popped, not run), and it runs once sync is back on.
  func testServerLanes_runningWorkerStopsAfterItsCurrentTask_whenGatedMidLane() async throws {
    let service = makeGatedEngine()
    let client = BlockingNetworkClient()
    service.networkClient = client
    for (id, path) in [("del-1", "a.mp3"), ("del-2", "b.mp3")] {
      try await repository.storeTask(parameters: [
        "id": id,
        "uuid": UUID().uuidString,
        "jobType": SyncJobType.delete.rawValue,
        "queueKey": TaskQueueKey.sync,
        "relativePath": path,
      ])
    }

    service.setServerLanesEnabled(true)
    try await client.waitForRequests(1)
    service.setServerLanesEnabled(false)
    client.release()

    try await waitForTaskCount(exactly: 1)
    try await Task.sleep(for: .milliseconds(300))
    let held = await repository.getAllTasks()
    XCTAssertEqual(held.map(\.id), ["del-2"])
    XCTAssertEqual(client.requestCount, 1, "the held task must not reach the server")

    service.setServerLanesEnabled(true)
    try await waitForEmptyQueue()
    XCTAssertEqual(client.requestCount, 2)
  }

  private func waitForTaskCount(exactly count: Int, timeout: TimeInterval = 3) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if await repository.getAllTasks().count == count { return }
      try await Task.sleep(for: .milliseconds(50))
    }
    XCTFail("timed out waiting for exactly \(count) task(s)")
  }

  /// Provider pushes go to the user's own media server, on every tier: the gate leaves them alone.
  func testProviderLanes_runWhileServerLanesAreGated() async throws {
    let service = makeGatedEngine()
    // Non-finite position: the engine discards (pops) it without any network call
    var params = externalUpdateParams(id: "push-1")
    params["currentTime"] = Double.infinity
    try await repository.storeTask(parameters: params)

    service.wakeUpWorkers()
    try await waitForEmptyQueue()
    XCTAssertFalse(service.serverLanesEnabled)
  }

  /// SyncService is the one writer: setup seeds the gate from `isActive`, and every
  /// enable/disable and logout moves it with the flag.
  @MainActor
  func testSyncService_drivesTheServerLaneGate() async throws {
    let queue = makeGatedEngine()
    let sync = SyncService()
    sync.setup(
      isActive: false,
      libraryService: LibraryService(),
      accountService: AccountServiceMock(account: nil),
      syncQueueService: queue,
      client: NetworkClientMock(mockedResponse: Empty())
    )
    XCTAssertFalse(queue.serverLanesEnabled)

    sync.updateSyncEnabled(true)
    try await waitUntil { queue.serverLanesEnabled }
    XCTAssertTrue(sync.isActive)

    sync.updateSyncEnabled(false)
    try await waitUntil { !queue.serverLanesEnabled }

    sync.updateSyncEnabled(true)
    try await waitUntil { queue.serverLanesEnabled }
    await sync.logout()
    XCTAssertFalse(queue.serverLanesEnabled)
    XCTAssertFalse(sync.isActive)
  }

  @MainActor
  private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTFail("timed out waiting for the condition")
  }
}

/// Answers `Empty` like `NetworkClientMock`, but holds the FIRST request until `release()`,
/// so a test can act while an operation is in flight.
private final class BlockingNetworkClient: NetworkClientMock, @unchecked Sendable {
  private let lock = NSLock()
  private var _requestCount = 0
  private var gate: CheckedContinuation<Void, Never>?
  private var released = false

  var requestCount: Int { lock.withLock { _requestCount } }

  init() { super.init(mockedResponse: Empty()) }

  override func request<T: Decodable>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T {
    let isFirst = lock.withLock {
      _requestCount += 1
      return _requestCount == 1 && !released
    }
    if isFirst {
      await withCheckedContinuation { continuation in
        let resumeNow = lock.withLock {
          if released { return true }
          gate = continuation
          return false
        }
        if resumeNow { continuation.resume() }
      }
    }
    // swiftlint:disable:next force_cast
    return Empty() as! T
  }

  func release() {
    let continuation = lock.withLock {
      released = true
      defer { gate = nil }
      return gate
    }
    continuation?.resume()
  }

  func waitForRequests(_ count: Int, timeout: TimeInterval = 3) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if requestCount >= count { return }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTFail("timed out waiting for \(count) request(s)")
  }
}

// MARK: - Parking (coded server errors)

extension SyncQueueTests {
  private func coded(_ code: String, status: Int = 404) -> BookPlayerError {
    .networkErrorWithCode(message: "Item not found: \"a.mp3\"", code: code, status: status)
  }

  private func syncTaskParams(id: String, jobType: SyncJobType, path: String) -> [String: Any] {
    [
      "id": id,
      "uuid": UUID().uuidString,
      "jobType": jobType.rawValue,
      "queueKey": TaskQueueKey.sync,
      "relativePath": path,
    ]
  }

  private func pause(_ scope: TaskPauseScope, code: String = "item_not_found") -> TaskPause {
    TaskPause(scope: scope, errorCode: code, message: "msg", httpStatus: 404, pausedAt: Date())
  }

  func testFailurePolicy_parksOnlyCodedErrors_scopedByJobType() {
    typealias Policy = SyncFailurePolicy
    XCTAssertEqual(Policy.action(for: nil, jobType: .move, parkingEnabled: true), .retry)
    XCTAssertEqual(Policy.action(for: BookPlayerError.networkError("x"), jobType: .move, parkingEnabled: true), .retry)
    XCTAssertEqual(Policy.action(for: URLError(.timedOut), jobType: .move, parkingEnabled: true), .retry)

    XCTAssertEqual(Policy.action(for: coded("item_not_found"), jobType: .move, parkingEnabled: true), .park(.lane))
    XCTAssertEqual(Policy.action(for: coded("uuid_conflict", status: 409), jobType: .upload, parkingEnabled: true), .park(.lane))
    XCTAssertEqual(Policy.action(for: coded("item_not_found"), jobType: .matchUuid, parkingEnabled: true), .park(.lane))
    XCTAssertEqual(Policy.action(for: coded("item_not_found"), jobType: .setBookmark, parkingEnabled: true), .park(.lane))
    XCTAssertEqual(Policy.action(for: coded("invalid_request", status: 400), jobType: .update, parkingEnabled: true), .park(.task))
    XCTAssertEqual(Policy.action(for: coded("item_not_found"), jobType: .uploadArtwork, parkingEnabled: true), .park(.task))

    XCTAssertEqual(Policy.action(for: coded("not_subscribed", status: 400), jobType: .move, parkingEnabled: true), .verifyAccount)
    XCTAssertEqual(Policy.action(for: coded("tier_required", status: 403), jobType: .uploadFile, parkingEnabled: true), .verifyAccount)

    // Watch: task-level failures drop, account-level handling is the same
    XCTAssertEqual(Policy.action(for: coded("item_not_found"), jobType: .move, parkingEnabled: false), .drop)
    XCTAssertEqual(Policy.action(for: coded("not_subscribed", status: 400), jobType: .move, parkingEnabled: false), .verifyAccount)

    // Media-server pushes keep their own handling, account codes included
    XCTAssertEqual(Policy.action(for: coded("item_not_found"), jobType: .externalUpdate, parkingEnabled: true), .retry)
    XCTAssertEqual(Policy.action(for: coded("not_subscribed", status: 400), jobType: .externalUpdate, parkingEnabled: true), .retry)

    // A logout/lapse cancellation is not the server's answer
    XCTAssertEqual(Policy.action(for: BookPlayerError.cancelledTask, jobType: .move, parkingEnabled: true), .retry)
  }

  func testGetNextTask_skipsTaskPausedRows_andStopsAtALanePause() async throws {
    try await repository.storeTask(parameters: syncTaskParams(id: "t1", jobType: .update, path: "a.mp3"))
    try await repository.storeTask(parameters: syncTaskParams(id: "t2", jobType: .shallowDelete, path: "b.mp3"))
    try await repository.storeTask(parameters: syncTaskParams(id: "t3", jobType: .delete, path: "c.mp3"))

    await repository.park(taskId: "t1", pause: pause(.task))
    var next = await repository.getNextTask(for: TaskQueueKey.sync)
    XCTAssertEqual(next?.id, "t2", "a task-level pause lets the rest of the lane run")

    await repository.park(taskId: "t2", pause: pause(.lane))
    next = await repository.getNextTask(for: TaskQueueKey.sync)
    XCTAssertNil(next, "a lane-level pause holds every later task")

    await repository.resume(taskId: "t2")
    next = await repository.getNextTask(for: TaskQueueKey.sync)
    XCTAssertEqual(next?.id, "t2")
  }

  func testAccountPause_holdsEveryServerLane_butNotProviderLanes() async throws {
    try await repository.storeTask(parameters: syncTaskParams(id: "s1", jobType: .shallowDelete, path: "a.mp3"))
    try await repository.storeTask(parameters: syncTaskParams(id: "s2", jobType: .delete, path: "b.mp3"))
    try await repository.storeTask(parameters: uploadFileParams(id: "u1"))
    try await repository.storeTask(parameters: externalUpdateParams(id: "j1"))

    await repository.park(taskId: "s1", pause: pause(.account, code: "not_subscribed"))
    await repository.park(taskId: "s2", pause: pause(.account, code: "not_subscribed"))

    let sync = await repository.getNextTask(for: TaskQueueKey.sync)
    let upload = await repository.getNextTask(for: TaskQueueKey.uploadFile)
    let push = await repository.getNextTask(for: "jellyfin")
    XCTAssertNil(sync)
    XCTAssertNil(upload)
    XCTAssertEqual(push?.id, "j1")

    // One cause: resuming one account pause resumes them all
    await repository.resume(taskId: "s1")
    let resumedUpload = await repository.getNextTask(for: TaskQueueKey.uploadFile)
    let resumedSync = await repository.getNextTask(for: TaskQueueKey.sync)
    XCTAssertEqual(resumedUpload?.id, "u1")
    XCTAssertEqual(resumedSync?.id, "s1")
    XCTAssertNil(resumedSync?.pause)
  }

  func testResumeAllPaused_keepsTheSentryEventId() async throws {
    try await repository.storeTask(parameters: syncTaskParams(id: "t1", jobType: .shallowDelete, path: "a.mp3"))
    await repository.park(taskId: "t1", pause: pause(.lane))
    await repository.setSentryEventId("evt-1", forTask: "t1")

    var stored = await repository.getAllTasks().first
    XCTAssertEqual(stored?.pause?.errorCode, "item_not_found")
    XCTAssertEqual(stored?.pause?.message, "msg")
    XCTAssertEqual(stored?.pause?.httpStatus, 404)
    XCTAssertEqual(stored?.pause?.sentryEventId, "evt-1")

    await repository.resumeAllPaused()
    stored = await repository.getAllTasks().first
    XCTAssertNil(stored?.pause)

    let reparked = await repository.park(taskId: "t1", pause: pause(.lane))
    XCTAssertEqual(reparked?.sentryEventId, "evt-1", "a re-park must not be reported again")

    let gone = await repository.park(taskId: "missing", pause: pause(.lane))
    XCTAssertNil(gone)
  }

  /// New work never merges into a parked task (it would wait behind the failure); it lands
  /// in a task of its own, which later updates may merge into as usual
  func testCoalescing_skipsParkedTasks() async throws {
    var first = syncTaskParams(id: "u1", jobType: .update, path: "a.mp3")
    first["uuid"] = "book-1"
    try await repository.storeTask(parameters: first)
    await repository.park(taskId: "u1", pause: pause(.task))

    var second = syncTaskParams(id: "u2", jobType: .update, path: "a.mp3")
    second["uuid"] = "book-1"
    try await repository.storeTask(parameters: second)
    var third = syncTaskParams(id: "u3", jobType: .update, path: "a.mp3")
    third["uuid"] = "book-1"
    try await repository.storeTask(parameters: third)

    let ids = await repository.getAllTasks().map(\.id)
    XCTAssertEqual(ids, ["u1", "u2"], "u2 stands apart from the parked u1; u3 merges into u2")
  }

  /// A parked task behind the runnable head is still never a merge target
  func testCoalescing_skipsAParkedTaskBehindTheHead() async throws {
    var head = syncTaskParams(id: "h1", jobType: .update, path: "h.mp3")
    head["uuid"] = "book-head"
    try await repository.storeTask(parameters: head)
    var parked = syncTaskParams(id: "p1", jobType: .update, path: "a.mp3")
    parked["uuid"] = "book-1"
    try await repository.storeTask(parameters: parked)
    await repository.park(taskId: "p1", pause: pause(.task))

    var newer = syncTaskParams(id: "p2", jobType: .update, path: "a.mp3")
    newer["uuid"] = "book-1"
    try await repository.storeTask(parameters: newer)

    let ids = await repository.getAllTasks().map(\.id)
    XCTAssertEqual(ids, ["h1", "p1", "p2"])
  }

  /// A Retry puts the resumed task ahead of the one running: the running task's parameters
  /// were already read, so merging into it would lose the new update
  func testCoalescing_neverMergesIntoTheRunningTask_afterARetryReordersTheLane() async throws {
    var parked = syncTaskParams(id: "r1", jobType: .update, path: "a.mp3")
    parked["uuid"] = "book-1"
    try await repository.storeTask(parameters: parked)
    await repository.park(taskId: "r1", pause: pause(.task))
    var running = syncTaskParams(id: "r2", jobType: .update, path: "b.mp3")
    running["uuid"] = "book-2"
    try await repository.storeTask(parameters: running)

    let picked = await repository.getNextTask(for: TaskQueueKey.sync)
    XCTAssertEqual(picked?.id, "r2")
    await repository.resume(taskId: "r1")

    var newer = syncTaskParams(id: "r3", jobType: .update, path: "b.mp3")
    newer["uuid"] = "book-2"
    try await repository.storeTask(parameters: newer)

    let ids = await repository.getAllTasks().map(\.id)
    XCTAssertEqual(ids, ["r1", "r2", "r3"])
  }

  func testQueueCounts_reportPausedAndBlockedLanes() async throws {
    try await repository.storeTask(parameters: syncTaskParams(id: "t1", jobType: .update, path: "a.mp3"))
    try await repository.storeTask(parameters: uploadFileParams(id: "u1"))
    await repository.park(taskId: "t1", pause: pause(.task))

    var counts = try await awaitCounts(from: tasksDataManager.observeQueueCounts()) { $0.totalPaused == 1 }
    XCTAssertEqual(counts.pausedCount(in: TaskQueueKey.sync), 1)
    XCTAssertFalse(counts.isBlocked(TaskQueueKey.sync))
    XCTAssertTrue(counts.isIdle(TaskQueueKey.sync), "only parked tasks left: nothing to wait for")
    XCTAssertFalse(counts.isIdle(TaskQueueKey.uploadFile))

    try await repository.storeTask(parameters: syncTaskParams(id: "t2", jobType: .shallowDelete, path: "b.mp3"))
    await repository.park(taskId: "t2", pause: pause(.account, code: "not_subscribed"))
    counts = try await awaitCounts(from: tasksDataManager.observeQueueCounts()) { $0.totalPaused == 2 }
    XCTAssertTrue(counts.isBlocked(TaskQueueKey.sync))
    XCTAssertTrue(counts.isBlocked(TaskQueueKey.uploadFile))
    XCTAssertEqual(counts.count(in: TaskQueueKey.sync), 2)
  }

  func testLaneDrained_treatsABlockedLaneAsDrained() {
    let subject = CurrentValueSubject<QueueCounts, Never>(
      QueueCounts(byQueueKey: [TaskQueueKey.sync: 2])
    )
    var seen = [Bool]()
    let subscription = subject.laneDrained(TaskQueueKey.sync).sink { seen.append($0) }
    defer { subscription.cancel() }

    subject.send(QueueCounts(byQueueKey: [TaskQueueKey.sync: 2], pausedByQueueKey: [TaskQueueKey.sync: 1]))
    subject.send(QueueCounts(
      byQueueKey: [TaskQueueKey.sync: 2],
      pausedByQueueKey: [TaskQueueKey.sync: 1],
      blockedQueueKeys: [TaskQueueKey.sync]
    ))

    XCTAssertEqual(seen, [false, false, true])
  }

  // MARK: Engine

  private func makeParkingEngine(
    client: NetworkClientProtocol,
    verify: @escaping () async -> AccessLevel? = { .pro }
  ) -> SyncQueueService {
    let service = makeGatedEngine()
    service.networkClient = client
    service.verifyAccessLevel = verify
    return service
  }

  private func waitForPause(of taskId: String, timeout: TimeInterval = 3) async throws -> TaskPause? {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if let pause = await repository.getAllTasks().first(where: { $0.id == taskId })?.pause { return pause }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTFail("timed out waiting for \(taskId) to park")
    return nil
  }

  /// A structural task that can never succeed stops its lane at once (no 5 s retry loop),
  /// is reported once, and Retry runs it again
  func testCodedFailure_parksAStructuralTask_holdsTheLane_andRetryRunsIt() async throws {
    let client = FailingNetworkClient(errors: [coded("item_not_found")])
    let service = makeParkingEngine(client: client)
    try await repository.storeTask(parameters: syncTaskParams(id: "e3m1", jobType: .delete, path: "a.mp3"))
    try await repository.storeTask(parameters: syncTaskParams(id: "e3m2", jobType: .delete, path: "b.mp3"))

    let reported = expectation(forNotification: .syncTaskPaused, object: nil) { note in
      (note.object as? QueuedSyncTask)?.id == "e3m1"
    }
    service.setServerLanesEnabled(true)

    let pause = try await waitForPause(of: "e3m1")
    XCTAssertEqual(pause?.scope, .lane)
    XCTAssertEqual(pause?.errorCode, "item_not_found")
    XCTAssertEqual(pause?.httpStatus, 404)
    await fulfillment(of: [reported], timeout: 2)

    try await Task.sleep(for: .milliseconds(300))
    XCTAssertEqual(client.requestCount, 1, "the lane waits behind the parked task")

    await service.retryPausedTask(id: "e3m1")
    try await waitForEmptyQueue()
    XCTAssertEqual(client.requestCount, 3)
  }

  func testCodedFailure_onALeafTask_parksItAlone() async throws {
    let client = FailingNetworkClient(errors: [coded("invalid_request", status: 400)])
    let service = makeParkingEngine(client: client)
    try await repository.storeTask(parameters: syncTaskParams(id: "e4a1", jobType: .update, path: "a.mp3"))
    try await repository.storeTask(parameters: syncTaskParams(id: "e4d1", jobType: .delete, path: "b.mp3"))

    service.setServerLanesEnabled(true)
    try await waitForTaskCount(exactly: 1)
    let left = await repository.getAllTasks()
    XCTAssertEqual(left.map(\.id), ["e4a1"])
    XCTAssertEqual(left.first?.pause?.scope, .task)
  }

  func testCodedFailure_withParkingDisabled_dropsTheTask() async throws {
    let client = FailingNetworkClient(errors: [coded("item_not_found")])
    let service = makeParkingEngine(client: client)
    service.parkingEnabled = false
    try await repository.storeTask(parameters: syncTaskParams(id: "e5m1", jobType: .delete, path: "a.mp3"))
    try await repository.storeTask(parameters: syncTaskParams(id: "e5m2", jobType: .delete, path: "b.mp3"))

    service.setServerLanesEnabled(true)
    try await waitForEmptyQueue()
    XCTAssertEqual(client.requestCount, 2)
  }

  /// RevenueCat still says active: every server lane holds and the pause is reported
  func testAccountRejection_whileRevenueCatSaysActive_holdsTheServerLanes_andReports() async throws {
    let client = FailingNetworkClient(errors: [coded("not_subscribed", status: 400)])
    let service = makeParkingEngine(client: client, verify: { .pro })
    try await repository.storeTask(parameters: syncTaskParams(id: "e7m1", jobType: .delete, path: "a.mp3"))

    let reported = expectation(forNotification: .syncTaskPaused, object: nil) { note in
      (note.object as? QueuedSyncTask)?.pause?.scope == .account
    }
    service.setServerLanesEnabled(true)

    let pause = try await waitForPause(of: "e7m1")
    XCTAssertEqual(pause?.scope, .account)
    await fulfillment(of: [reported], timeout: 2)

    // An upload that would otherwise run (its missing file is consumed without network)
    var upload = uploadFileParams(id: "e7u1")
    upload["filePath"] = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).m4b").absoluteString
    try await repository.storeTask(parameters: upload)
    service.wakeUpWorkers()
    try await Task.sleep(for: .milliseconds(300))
    let held = await repository.getAllTasks()
    XCTAssertEqual(Set(held.map(\.id)), ["e7m1", "e7u1"], "the upload lane holds too")
    let counts = try await awaitCounts(from: tasksDataManager.observeQueueCounts()) {
      $0.count(in: TaskQueueKey.uploadFile) == 1
    }
    XCTAssertTrue(counts.isBlocked(TaskQueueKey.uploadFile))
  }

  /// RevenueCat confirms the lapse: nothing is reported (the lapse path clears the lanes)
  func testAccountRejection_confirmedInactive_isNotReported() async throws {
    let client = FailingNetworkClient(errors: [coded("not_subscribed", status: 400)])
    let verified = expectation(description: "entitlement checked")
    let service = makeParkingEngine(client: client, verify: {
      verified.fulfill()
      return .free
    })
    try await repository.storeTask(parameters: syncTaskParams(id: "e9m1", jobType: .delete, path: "a.mp3"))

    // Filtered on this test's task: the notification is global, and an earlier test's
    // engine may still post late
    let reported = expectation(forNotification: .syncTaskPaused, object: nil) { note in
      (note.object as? QueuedSyncTask)?.id == "e9m1"
    }
    reported.isInverted = true
    service.setServerLanesEnabled(true)

    await fulfillment(of: [verified], timeout: 2)
    await fulfillment(of: [reported], timeout: 0.5)
  }

  /// A LITE account at a route that needs PRO (artwork here): the server was right, so the
  /// task is dropped without a report, and the lanes it held run again
  func testTierRequired_onAProOnlyTask_whenRevenueCatSaysLite_dropsIt_andTheLanesRun() async throws {
    let path = "tier-\(UUID().uuidString).m4b"
    let artwork = ArtworkService.getCachedImageURL(for: path)
    try FileManager.default.createDirectory(
      at: artwork.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data([0xFF, 0xD8]).write(to: artwork)
    defer { try? FileManager.default.removeItem(at: artwork) }

    let client = FailingNetworkClient(errors: [coded("tier_required", status: 403)])
    let service = makeParkingEngine(client: client, verify: { .lite })
    try await repository.storeTask(parameters: syncTaskParams(id: "e12a1", jobType: .uploadArtwork, path: path))
    try await repository.storeTask(parameters: syncTaskParams(id: "e12m1", jobType: .delete, path: "b.mp3"))

    let reported = expectation(forNotification: .syncTaskPaused, object: nil) { note in
      (note.object as? QueuedSyncTask)?.id == "e12a1"
    }
    reported.isInverted = true
    service.setServerLanesEnabled(true)

    try await waitForEmptyQueue()
    XCTAssertEqual(client.requestCount, 2, "the refused artwork, then the delete it held")
    await fulfillment(of: [reported], timeout: 0.5)
  }

  /// The fresh read is judged by the task's route: the S3 ones (book files, artwork) need
  /// PRO, every other one either sync tier
  func testAccountVerdict_judgesByTheTasksRoute() {
    for jobType in [SyncJobType.uploadFile, .uploadArtwork] {
      XCTAssertEqual(SyncFailurePolicy.accountVerdict(for: jobType, freshLevel: .lite), .lacksPro)
      XCTAssertEqual(SyncFailurePolicy.accountVerdict(for: jobType, freshLevel: .pro), .disputed)
    }
    for jobType in [SyncJobType.update, .delete, .upload] {
      XCTAssertEqual(SyncFailurePolicy.accountVerdict(for: jobType, freshLevel: .lite), .disputed)
    }
    for level in [AccessLevel.free, .plus] {
      XCTAssertEqual(SyncFailurePolicy.accountVerdict(for: .uploadFile, freshLevel: level), .lapsed)
      XCTAssertEqual(SyncFailurePolicy.accountVerdict(for: .delete, freshLevel: level), .lapsed)
    }
    XCTAssertEqual(SyncFailurePolicy.accountVerdict(for: .uploadArtwork, freshLevel: nil), .disputed)
  }

  /// The one automatic retry: a launch resumes parked tasks before waking the lanes
  func testLaunchWake_resumesParkedTasks() async throws {
    let service = makeParkingEngine(client: FailingNetworkClient(errors: []))
    try await repository.storeTask(parameters: syncTaskParams(id: "e11m1", jobType: .delete, path: "a.mp3"))
    await repository.park(taskId: "e11m1", pause: pause(.lane))
    service.setServerLanesEnabled(true)
    try await Task.sleep(for: .milliseconds(300))
    let stillParked = await repository.getAllTasks()
    XCTAssertEqual(stillParked.count, 1, "an ordinary wake leaves parked tasks alone")

    service.wakeUpWorkers(resumingPausedTasks: true)
    try await waitForEmptyQueue()
  }
}

/// Throws the queued errors for the first requests, then answers `Empty`
private final class FailingNetworkClient: NetworkClientMock, @unchecked Sendable {
  private let lock = NSLock()
  private var errors: [Error]
  private var _requestCount = 0

  var requestCount: Int { lock.withLock { _requestCount } }

  init(errors: [Error]) {
    self.errors = errors
    super.init(mockedResponse: Empty())
  }

  override func request<T: Decodable>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T {
    let error: Error? = lock.withLock {
      _requestCount += 1
      return errors.isEmpty ? nil : errors.removeFirst()
    }
    if let error { throw error }
    // swiftlint:disable:next force_cast
    return Empty() as! T
  }
}

// MARK: - Multipart upload state and API

extension SyncQueueTests {
  /// A relaunch must resume the same S3 upload: what's saved comes back with the task
  func testUploadState_roundTripsThroughTheTask() async throws {
    try await repository.storeTask(parameters: uploadFileParams(id: "mp1"))
    var loaded = await repository.getNextTask(for: TaskQueueKey.uploadFile)
    XCTAssertEqual(
      MultipartUploadState(parameters: loaded?.parameters ?? [:]),
      MultipartUploadState(uploadId: nil, partSize: 0, fileSize: 0, restartCount: 0)
    )

    let state = MultipartUploadState(
      uploadId: "upload-1",
      partSize: 64 * 1024 * 1024,
      fileSize: 6_000_000_000,
      restartCount: 2
    )
    await repository.saveUploadState(state, forTask: "mp1")
    loaded = await repository.getNextTask(for: TaskQueueKey.uploadFile)
    XCTAssertEqual(MultipartUploadState(parameters: loaded?.parameters ?? [:]), state)

    // Forgetting the upload (before a fresh start) keeps the rest
    var forgotten = state
    forgotten.uploadId = nil
    await repository.saveUploadState(forgotten, forTask: "mp1")
    loaded = await repository.getNextTask(for: TaskQueueKey.uploadFile)
    XCTAssertEqual(MultipartUploadState(parameters: loaded?.parameters ?? [:]), forgotten)
  }

  func testMultipartRoutes_matchTheServerContract() {
    let start = LibraryAPI.startUpload(uuid: "u", fileSize: 6_000_000_000, partSize: 67_108_864)
    XCTAssertEqual(start.path, "/v1/library/upload/start")
    XCTAssertEqual(start.method, .post)
    XCTAssertEqual(start.parameters?["fileSize"] as? Int64, 6_000_000_000)
    XCTAssertEqual(start.parameters?["partSize"] as? Int, 67_108_864)

    let urls = LibraryAPI.uploadPartURLs(uuid: "u", uploadId: "x", partNumbers: [1, 2])
    XCTAssertEqual(urls.path, "/v1/library/upload/parts")
    XCTAssertEqual(urls.method, .post)
    XCTAssertEqual(urls.parameters?["partNumbers"] as? [Int], [1, 2])

    let parts = LibraryAPI.uploadedParts(uuid: "u", uploadId: "x")
    XCTAssertEqual(parts.path, "/v1/library/upload/parts")
    XCTAssertEqual(parts.method, .get)

    let complete = LibraryAPI.completeUpload(uuid: "u", uploadId: "x", partCount: 90, fileSize: 6_000_000_000)
    XCTAssertEqual(complete.path, "/v1/library/upload/complete")
    XCTAssertEqual(complete.parameters?["partCount"] as? Int, 90)

    let abort = LibraryAPI.abortUpload(uuid: "u", uploadId: "x")
    XCTAssertEqual(abort.path, "/v1/library/upload/abort")
    XCTAssertEqual(abort.method, .post)
  }

  func testMultipartResponses_decode() throws {
    let decoder = JSONDecoder()
    let started = try decoder.decode(
      StartUploadResponse.self,
      from: Data(#"{"status":"started","uploadId":"x","partSize":67108864,"partCount":90}"#.utf8)
    )
    XCTAssertEqual(started.status, .started)
    XCTAssertEqual(started.partCount, 90)

    let exists = try decoder.decode(StartUploadResponse.self, from: Data(#"{"status":"exists"}"#.utf8))
    XCTAssertEqual(exists.status, .exists)
    XCTAssertNil(exists.uploadId)

    let urls = try decoder.decode(
      UploadPartURLsResponse.self,
      from: Data(#"{"parts":[{"partNumber":3,"url":"https://s3/p3","expiresAt":1790000000}]}"#.utf8)
    )
    XCTAssertEqual(urls.parts.first?.partNumber, 3)

    let uploaded = try decoder.decode(
      UploadedPartsResponse.self,
      from: Data(#"{"parts":[{"partNumber":1,"size":67108864}]}"#.utf8)
    )
    XCTAssertEqual(uploaded.parts.first?.size, 67_108_864)
  }
}

// MARK: - Upload lane wiring

extension SyncQueueTests {
  /// End to end through the engine: the upload task's operation runs, its local refusal
  /// reaches the parking policy, and the task parks alone with the app's own reason,
  /// unreported (an expected limit, not a failure)
  func testTooLargeUpload_parksTheTaskWithItsLocalReason() async throws {
    let service = makeGatedEngine()
    let reported = expectation(forNotification: .syncTaskPaused, object: nil) { note in
      (note.object as? QueuedSyncTask)?.id == "huge"
    }
    reported.isInverted = true
    let link = FileManager.default.temporaryDirectory.appendingPathComponent("huge-\(UUID().uuidString).m4b")
    FileManager.default.createFile(atPath: link.path, contents: nil)
    let handle = try FileHandle(forWritingTo: link)
    try handle.truncate(atOffset: UInt64(FileUploadOperation.maxFileSize) + 1)
    try handle.close()
    defer { try? FileManager.default.removeItem(at: link) }
    var params = uploadFileParams(id: "huge")
    params["filePath"] = link.absoluteString
    try await repository.storeTask(parameters: params)

    service.setServerLanesEnabled(true)

    let deadline = Date().addingTimeInterval(3)
    var pause: TaskPause?
    while Date() < deadline {
      pause = await repository.getAllTasks().first?.pause
      if pause != nil { break }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertEqual(pause?.scope, .task)
    XCTAssertEqual(pause?.errorCode, "file_too_large")
    XCTAssertNil(pause?.httpStatus)
    XCTAssertTrue(FileManager.default.fileExists(atPath: link.path), "the link stays for a Retry")
    await fulfillment(of: [reported], timeout: 0.5)
  }
}

// MARK: - Sync-lane hand-offs to the upload lane

extension SyncQueueTests {
  private func syncableItem(uuid: String, mediaServer: Bool) throws -> SyncableItem {
    let resources = mediaServer
      ? #","externalResources":[{"providerName":"jellyfin","providerId":"jf-1","syncStatus":"stream"}]"#
      : ""
    let json = #"{"relativePath":"Book.m4b","originalFileName":"Book.m4b","title":"Book","isFinished":false,"type":2,"uuid":"\#(uuid)"\#(resources)}"#
    return try JSONDecoder().decode(SyncableItem.self, from: Data(json.utf8))
  }

  /// The upload lane hit `item_not_found`: the book is registered again through the sync
  /// lane (from its current state), and this upload task is gone
  private func runHandBack(item: SyncableItem?) async throws -> [QueuedSyncTask] {
    let service = makeGatedEngine()
    // `start` answers item_not_found; everything after (the re-registration) just fails,
    // so the new sync task stays queued for the assertions
    service.networkClient = FailingNetworkClient(
      errors: [BookPlayerError.networkErrorWithCode(message: "gone", code: "item_not_found", status: 404)]
        + Array(repeating: URLError(.timedOut), count: 50)
    )
    service.findSyncableItem = { _ in item }
    let link = FileManager.default.temporaryDirectory.appendingPathComponent("handback-\(UUID().uuidString).m4b")
    try Data("0123456789".utf8).write(to: link)
    defer { try? FileManager.default.removeItem(at: link) }
    var params = uploadFileParams(id: "lost")
    params["filePath"] = link.absoluteString
    params["uuid"] = item?.uuid ?? UUID().uuidString
    try await repository.storeTask(parameters: params)

    service.setServerLanesEnabled(true)

    let deadline = Date().addingTimeInterval(3)
    var tasks = [QueuedSyncTask]()
    while Date() < deadline {
      tasks = await repository.getAllTasks()
      if !tasks.contains(where: { $0.id == "lost" }) { break }
      try await Task.sleep(for: .milliseconds(20))
    }
    service.setServerLanesEnabled(false)
    return tasks
  }

  func testUploadOfABookTheServerLost_registersItAgain() async throws {
    let uuid = UUID().uuidString
    let tasks = try await runHandBack(item: try syncableItem(uuid: uuid, mediaServer: false))

    XCTAssertFalse(tasks.contains { $0.id == "lost" })
    XCTAssertEqual(tasks.map(\.jobType), [.upload])
    XCTAssertEqual(tasks.first?.uuid, uuid)
    XCTAssertNil(tasks.first?.pause)
  }

  /// A media-server book's re-registration carries `provider`, which never schedules the
  /// file: the pipe job follows it so the file still goes up
  func testUploadOfAMediaServerBookTheServerLost_alsoQueuesItsFile() async throws {
    let tasks = try await runHandBack(item: try syncableItem(uuid: UUID().uuidString, mediaServer: true))

    // The item, its media-server link (so `complete` has a resource to mark downloaded),
    // then its file
    XCTAssertEqual(tasks.map(\.jobType), [.upload, .externalResource, .externalResourceToDownload])
  }

  /// Re-registering didn't help (e.g. another uuid holds the key on the server): the second
  /// item_not_found for the same book parks it instead of cycling PUT + start forever
  func testSecondItemNotFound_forTheSameBook_parksInsteadOfCycling() async throws {
    let service = makeGatedEngine()
    let lost = BookPlayerError.networkErrorWithCode(message: "gone", code: "item_not_found", status: 404)
    service.networkClient = FailingNetworkClient(errors: [lost, lost] + Array(repeating: URLError(.timedOut), count: 50))
    let uuid = UUID().uuidString
    service.findSyncableItem = { _ in nil }
    for id in ["first", "second"] {
      let link = FileManager.default.temporaryDirectory.appendingPathComponent("cycle-\(id)-\(UUID().uuidString).m4b")
      try Data("0123456789".utf8).write(to: link)
      var params = uploadFileParams(id: id)
      params["filePath"] = link.absoluteString
      params["uuid"] = uuid
      try await repository.storeTask(parameters: params)
    }

    service.setServerLanesEnabled(true)

    let deadline = Date().addingTimeInterval(10)
    var tasks = [QueuedSyncTask]()
    while Date() < deadline {
      tasks = await repository.getAllTasks()
      if tasks.map(\.id) == ["second"], tasks.first?.pause != nil { break }
      try await Task.sleep(for: .milliseconds(50))
    }
    service.setServerLanesEnabled(false)
    XCTAssertEqual(tasks.map(\.id), ["second"], "the first was handed back (dropped: gone locally), the second parks")
    XCTAssertEqual(tasks.first?.pause?.errorCode, "item_not_found")
    XCTAssertEqual(tasks.first?.pause?.scope, .task)
  }

  /// A Retry asks for the upload again: the book is handed back once more although it
  /// already was this session (gone locally here, so dropped) instead of parking again
  func testRetry_ofALostUploadThatParked_registersItAgain() async throws {
    let service = makeGatedEngine()
    let lost = BookPlayerError.networkErrorWithCode(message: "gone", code: "item_not_found", status: 404)
    service.networkClient = FailingNetworkClient(
      errors: [lost, lost, lost] + Array(repeating: URLError(.timedOut), count: 50)
    )
    let uuid = UUID().uuidString
    service.findSyncableItem = { _ in nil }
    for id in ["first", "second"] {
      let link = FileManager.default.temporaryDirectory.appendingPathComponent("retry-\(id)-\(UUID().uuidString).m4b")
      try Data("0123456789".utf8).write(to: link)
      var params = uploadFileParams(id: id)
      params["filePath"] = link.absoluteString
      params["uuid"] = uuid
      try await repository.storeTask(parameters: params)
    }

    service.setServerLanesEnabled(true)

    var deadline = Date().addingTimeInterval(10)
    var tasks = [QueuedSyncTask]()
    while Date() < deadline {
      tasks = await repository.getAllTasks()
      if tasks.map(\.id) == ["second"], tasks.first?.pause != nil { break }
      try await Task.sleep(for: .milliseconds(50))
    }
    XCTAssertEqual(tasks.first?.pause?.errorCode, "item_not_found", "parked before the Retry")

    await service.retryPausedTask(id: "second")

    deadline = Date().addingTimeInterval(10)
    while Date() < deadline {
      tasks = await repository.getAllTasks()
      if tasks.isEmpty || tasks.first?.pause != nil { break }
      try await Task.sleep(for: .milliseconds(50))
    }
    service.setServerLanesEnabled(false)
    XCTAssertTrue(tasks.isEmpty, "handed back again (dropped: gone locally), not parked again")
  }

  /// Only a media-server link marks a book as streamed: a Hardcover link has no file and
  /// must not stop the book's own file from uploading
  func testUploadJob_flagsOnlyMediaServerBooksAsProviderBacked() async throws {
    let scheduler = SyncJobScheduler(tasksRepository: repository)
    let hardcover = try JSONDecoder().decode(SyncableItem.self, from: Data(
      #"{"relativePath":"Local.m4b","originalFileName":"Local.m4b","title":"Local","isFinished":false,"type":2,"uuid":"\#(UUID().uuidString)","externalResources":[{"providerName":"hardcover","providerId":"hc-1","syncStatus":"not_synced"}]}"#.utf8
    ))
    let streamed = try syncableItem(uuid: UUID().uuidString, mediaServer: true)

    await scheduler.scheduleLibraryItemUploadJob(for: hardcover)
    await scheduler.scheduleLibraryItemUploadJob(for: streamed)

    let jobs = await repository.getAllTasksWithParams(in: TaskQueueKey.sync)
    XCTAssertEqual(jobs.count, 2)
    XCTAssertNil(jobs.first { $0.relativePath == "Local.m4b" }?.parameters["provider"])
    XCTAssertEqual(jobs.first { $0.relativePath == "Book.m4b" }?.parameters["provider"] as? String, "jellyfin")
  }

  func testUploadOfABookGoneEverywhere_isDropped() async throws {
    let tasks = try await runHandBack(item: nil)

    XCTAssertTrue(tasks.isEmpty)
  }

  /// A downloaded media-server book's file goes to S3 through the upload lane: the job's
  /// result schedules the upload of the local file (no server call of its own)
  func testMediaServerDownload_queuesTheUploadOfItsFile() async throws {
    let name = "pipe-\(UUID().uuidString).m4b"
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(name)
    try FileManager.default.createDirectory(at: DataManager.getProcessedFolderURL(), withIntermediateDirectories: true)
    try Data("0123456789".utf8).write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let uuid = UUID().uuidString
    let operation = LibraryItemSyncOperation(
      client: FailingNetworkClient(errors: []),
      task: SyncTask(
        id: "pipe",
        uuid: uuid,
        relativePath: name,
        jobType: .externalResourceToDownload,
        parameters: ["id": "pipe", "uuid": uuid, "relativePath": name]
      ),
      canUploadFiles: true
    )

    let done = expectation(description: "finished")
    let observer = operation.observe(\.isFinished, options: [.initial, .new]) { op, _ in
      if op.isFinished { done.fulfill() }
    }
    operation.start()
    await fulfillment(of: [done], timeout: 3)
    observer.invalidate()

    XCTAssertTrue(operation.didSucceed)
    guard case .uploadMetadata(let result) = operation.results else {
      return XCTFail("expected the file to be handed to the upload lane")
    }
    XCTAssertEqual(result.uuid, uuid)
    XCTAssertEqual(URL(string: result.filePath)?.path, fileURL.path)
  }
}

// MARK: - Dismiss (too-large uploads only)

extension SyncQueueTests {
  func testDismiss_removesATooLargeUploadAndItsLink() async throws {
    let service = makeGatedEngine()
    let link = FileManager.default.temporaryDirectory.appendingPathComponent("dismiss-\(UUID().uuidString).m4b")
    try Data("x".utf8).write(to: link)
    defer { try? FileManager.default.removeItem(at: link) }
    var params = uploadFileParams(id: "big")
    params["filePath"] = link.absoluteString
    try await repository.storeTask(parameters: params)
    await repository.park(
      taskId: "big",
      pause: TaskPause(scope: .task, errorCode: "file_too_large", message: "m", httpStatus: nil, pausedAt: Date())
    )

    service.dismissPausedTask(id: "big")

    try await waitForEmptyQueue()
    // The link goes right after the pop, off the actor
    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline, FileManager.default.fileExists(atPath: link.path) {
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: link.path))
  }

  func testDismiss_ignoresATaskThatIsNotParked() async throws {
    let service = makeGatedEngine()
    try await repository.storeTask(parameters: uploadFileParams(id: "pending"))

    service.dismissPausedTask(id: "pending")
    service.dismissPausedTask(id: "unknown")
    try await Task.sleep(for: .milliseconds(300))

    let tasks = await repository.getAllTasks()
    XCTAssertEqual(tasks.map(\.id), ["pending"])
  }

  /// Server-refused tasks never get a Skip: Dismiss refuses them
  func testDismiss_refusesAnyOtherPause() async throws {
    let service = makeGatedEngine()
    try await repository.storeTask(parameters: uploadFileParams(id: "refused"))
    await repository.park(
      taskId: "refused",
      pause: TaskPause(scope: .task, errorCode: "invalid_parts", message: "m", httpStatus: 422, pausedAt: Date())
    )

    service.dismissPausedTask(id: "refused")
    try await Task.sleep(for: .milliseconds(300))

    let tasks = await repository.getAllTasks()
    XCTAssertEqual(tasks.map(\.id), ["refused"])
  }
}

// MARK: - Settling uploads for a background wake

extension SyncQueueTests {
  /// Nothing will upload: the wake is answered right away
  func testSettleUploads_returnsAtOnceWhenNothingWillRun() async throws {
    let service = makeGatedEngine()

    let gatedStart = Date()
    await service.settleUploads()
    XCTAssertLessThan(Date().timeIntervalSince(gatedStart), 1, "sync off")

    service.setServerLanesEnabled(true)
    let emptyStart = Date()
    await service.settleUploads()
    XCTAssertLessThan(Date().timeIntervalSince(emptyStart), 1, "nothing queued")
    service.setServerLanesEnabled(false)
  }
}

// MARK: - Books waiting to upload (the continued task's view)

extension SyncQueueTests {
  func testPendingBookUploads_listsBothLanes_skippingFoldersAndParkedTasks() async throws {
    let service = makeGatedEngine()
    let link = FileManager.default.temporaryDirectory.appendingPathComponent("pending-\(UUID().uuidString).m4b")
    try Data("0123456789".utf8).write(to: link)
    defer { try? FileManager.default.removeItem(at: link) }

    var upload = uploadFileParams(id: "file")
    upload["filePath"] = link.absoluteString
    upload["uuid"] = "u-file"
    upload["relativePath"] = "Uploading.m4b"
    try await repository.storeTask(parameters: upload)
    var parkedUpload = uploadFileParams(id: "parked")
    parkedUpload["uuid"] = "u-parked"
    try await repository.storeTask(parameters: parkedUpload)
    await repository.park(
      taskId: "parked",
      pause: TaskPause(scope: .task, errorCode: "invalid_parts", message: "m", httpStatus: 422, pausedAt: Date())
    )
    let scheduler = SyncJobScheduler(tasksRepository: repository)
    let book = try JSONDecoder().decode(SyncableItem.self, from: Data(
      #"{"relativePath":"Next.m4b","originalFileName":"Next.m4b","title":"Next","isFinished":false,"type":2,"uuid":"u-book"}"#.utf8
    ))
    let folder = try JSONDecoder().decode(SyncableItem.self, from: Data(
      #"{"relativePath":"Folder","originalFileName":"Folder","title":"Folder","isFinished":false,"type":0,"uuid":"u-folder"}"#.utf8
    ))
    // A media-server book: its metadata upload carries `provider` and no file follows
    let streamed = try syncableItem(uuid: "u-streamed", mediaServer: true)
    await scheduler.scheduleLibraryItemUploadJob(for: book)
    await scheduler.scheduleLibraryItemUploadJob(for: folder)
    await scheduler.scheduleLibraryItemUploadJob(for: streamed)

    let pending = await service.pendingBookUploads()

    // The sync lane first, then the upload lane
    XCTAssertEqual(pending.books.map(\.uuid), ["u-book", "u-file"])
    XCTAssertEqual(pending.books.map(\.queueKey), [TaskQueueKey.sync, TaskQueueKey.uploadFile])
    XCTAssertEqual(pending.books.last?.fileSize, 10)
    XCTAssertEqual(pending.books.last?.fileName, "Uploading.m4b")
    XCTAssertEqual(pending.parkedCount, 1)
  }
}

// MARK: - The sync-to-upload hand-off

/// Answers the metadata upload with a URL (the server needs the bytes) and fails everything
/// else, so the upload lane just retries
private final class NeedsBytesNetworkClient: NetworkClientMock, @unchecked Sendable {
  init() { super.init(mockedResponse: Empty()) }

  override func request<T: Decodable>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T {
    guard path == "/v1/library", method == .put else { throw URLError(.timedOut) }
    let json = #"{"content":{"url":"https://s3.test/book"}}"#
    return try JSONDecoder().decode(T.self, from: Data(json.utf8))
  }
}

extension SyncQueueTests {
  /// The upload task is stored before the sync `.upload` is popped: at no point is the book
  /// in neither lane (a kill there would lose the upload; the continued task would count it
  /// done)
  func testMetadataUploadNeedingBytes_neverLeavesTheBookInNeitherLane() async throws {
    let service = makeGatedEngine()
    service.networkClient = NeedsBytesNetworkClient()
    let name = "handoff-\(UUID().uuidString).m4b"
    let bookURL = DataManager.getProcessedFolderURL().appendingPathComponent(name)
    try FileManager.default.createDirectory(at: DataManager.getProcessedFolderURL(), withIntermediateDirectories: true)
    try Data("0123456789".utf8).write(to: bookURL)
    defer {
      try? FileManager.default.removeItem(at: bookURL)
      try? FileManager.default.removeItem(at: SyncJobScheduler.hardLinkURL(for: name))
    }
    let book = try JSONDecoder().decode(SyncableItem.self, from: Data(
      #"{"relativePath":"\#(name)","originalFileName":"\#(name)","title":"Book","isFinished":false,"type":2,"uuid":"\#(UUID().uuidString)"}"#.utf8
    ))
    // Appended on main (the counts are delivered there), read there too
    nonisolated(unsafe) var snapshots = [QueueCounts]()
    let recording = tasksDataManager.observeQueueCounts().sink { snapshots.append($0) }
    defer { recording.cancel() }
    await SyncJobScheduler(tasksRepository: repository).scheduleLibraryItemUploadJob(for: book)

    service.setServerLanesEnabled(true)

    let deadline = Date().addingTimeInterval(3)
    while Date() < deadline {
      let tasks = await repository.getAllTasks()
      if tasks.map(\.jobType) == [.uploadFile] { break }
      try await Task.sleep(for: .milliseconds(20))
    }
    service.setServerLanesEnabled(false)
    try await Task.sleep(for: .milliseconds(50))
    let recorded = await MainActor.run { snapshots }

    XCTAssertEqual(recorded.last?.count(in: TaskQueueKey.uploadFile), 1)
    XCTAssertEqual(recorded.last?.count(in: TaskQueueKey.sync), 0)
    let firstQueued = recorded.firstIndex { $0.total > 0 } ?? 0
    XCTAssertFalse(
      recorded[firstQueued...].contains { $0.total == 0 },
      "the book was briefly in neither lane"
    )
  }
}

// MARK: - Upload confirmation by tier

/// Records each library request and answers the metadata upload with no URL
private final class NoURLLibraryClient: NetworkClientMock, @unchecked Sendable {
  private let lock = NSLock()
  private var _calls = [String]()
  private var _lastParameters: [String: Any]?

  var calls: [String] { lock.withLock { _calls } }
  var lastParameters: [String: Any]? { lock.withLock { _lastParameters } }

  init() {
    super.init(mockedResponse: Empty())
  }

  override func request<T: Decodable>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T {
    lock.withLock {
      _calls.append("\(method.rawValue) \(path)")
      _lastParameters = parameters
    }
    return try JSONDecoder().decode(T.self, from: Data(#"{"content":{"url":null}}"#.utf8))
  }
}

extension SyncQueueTests {
  private func runMetadataUpload(type: SimpleItemType, canUploadFiles: Bool) async throws -> NoURLLibraryClient {
    let client = NoURLLibraryClient()
    let uuid = UUID().uuidString
    let operation = LibraryItemSyncOperation(
      client: client,
      task: SyncTask(
        id: "meta",
        uuid: uuid,
        relativePath: "Tier-\(uuid).m4b",
        jobType: .upload,
        parameters: ["id": "meta", "uuid": uuid, "relativePath": "Tier-\(uuid).m4b", "type": type.rawValue]
      ),
      canUploadFiles: canUploadFiles
    )

    let done = expectation(description: "finished")
    let observer = operation.observe(\.isFinished, options: [.initial, .new]) { op, _ in
      if op.isFinished { done.fulfill() }
    }
    operation.start()
    await fulfillment(of: [done], timeout: 3)
    observer.invalidate()

    XCTAssertTrue(operation.didSucceed)
    return client
  }

  /// A book's `synced` means its file is in S3. Without S3 access, no URL only means the tier
  /// stores no file, so the book stays unconfirmed and its file can go up after an upgrade
  func testMetadataUploadWithoutS3Access_neverConfirmsABook() async throws {
    let client = try await runMetadataUpload(type: .book, canUploadFiles: false)

    XCTAssertEqual(client.calls, ["PUT /v1/library"])
  }

  /// With S3 access, no URL means the file is already there: the book is confirmed
  func testMetadataUploadWithS3Access_confirmsABookAlreadyStored() async throws {
    let client = try await runMetadataUpload(type: .book, canUploadFiles: true)

    XCTAssertEqual(client.calls, ["PUT /v1/library", "POST /v1/library"])
    XCTAssertEqual(client.lastParameters?["synced"] as? Bool, true)
  }

  /// Folders and bound books aren't confirmed by a file: they're confirmed on every tier
  func testMetadataUploadWithoutS3Access_stillConfirmsFoldersAndBoundBooks() async throws {
    for type in [SimpleItemType.folder, .bound] {
      let client = try await runMetadataUpload(type: type, canUploadFiles: false)

      XCTAssertEqual(client.calls, ["PUT /v1/library", "POST /v1/library"], "\(type)")
      XCTAssertEqual(client.lastParameters?["synced"] as? Bool, true, "\(type)")
    }
  }

  /// The queue hands its tier to the operation it builds: a book queued on a tier without
  /// S3 access is registered but never confirmed, and one queued on PRO is
  func testQueuedMetadataUpload_confirmsABookOnlyWithS3Access() async throws {
    for canUploadFiles in [false, true] {
      let service = makeGatedEngine()
      service.accessPolicy = [.uploadFile: canUploadFiles, .externalUpdate: true]
      let client = NoURLLibraryClient()
      service.networkClient = client
      let uuid = UUID().uuidString
      let book = try JSONDecoder().decode(SyncableItem.self, from: Data(
        #"{"relativePath":"Tier-\#(uuid).m4b","originalFileName":"Tier.m4b","title":"Tier","isFinished":false,"type":2,"uuid":"\#(uuid)"}"#.utf8
      ))
      await SyncJobScheduler(tasksRepository: repository).scheduleLibraryItemUploadJob(for: book)

      service.setServerLanesEnabled(true)
      try await waitForEmptyQueue()
      service.setServerLanesEnabled(false)

      XCTAssertEqual(
        client.calls,
        canUploadFiles ? ["PUT /v1/library", "POST /v1/library"] : ["PUT /v1/library"],
        "canUploadFiles: \(canUploadFiles)"
      )
    }
  }
}
