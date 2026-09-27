//
//  MultipartUploadEngineTests.swift
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

/// The multipart upload engine against a scripted server and a fake part transport:
/// 4-byte parts over a 10-byte file (3 parts)
final class MultipartUploadEngineTests: XCTestCase {
  private var repository: SyncQueueRepository!
  private var server: ScriptedUploadServer!
  private var transport: FakePartTransport!
  private var fileURL: URL!
  private let taskId = "upload-task"
  private let uuid = "book-uuid"

  override func setUpWithError() throws {
    let schema = Schema(versionedSchema: SchemaV3.self)
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: config)
    repository = SyncQueueRepository(tasksDataManager: TasksDataManager(container: container))
    server = ScriptedUploadServer()
    transport = FakePartTransport()
    transport.server = server
    fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("engine-\(UUID().uuidString).m4b")
    try Data("0123456789".utf8).write(to: fileURL)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: fileURL)
    try? FileManager.default.removeItem(at: FileUploadOperation.partsDirectory(for: uuid))
    repository = nil
    server = nil
    transport = nil
    super.tearDown()
  }

  private func storeTask() async throws {
    try await repository.storeTask(parameters: [
      "id": taskId,
      "uuid": uuid,
      "jobType": SyncJobType.uploadFile.rawValue,
      "queueKey": TaskQueueKey.uploadFile,
      "filePath": fileURL.absoluteString,
    ])
  }

  private func makeOperation(
    state: MultipartUploadState = .init(uploadId: nil, partSize: 0, fileSize: 0, restartCount: 0),
    libraryFileURL: @escaping (String) async -> URL? = { _ in nil }
  ) -> FileUploadOperation {
    FileUploadOperation(
      taskId: taskId,
      uuid: uuid,
      fileURL: fileURL,
      state: state,
      client: server,
      repository: repository,
      transport: transport,
      partSize: 4,
      // Never the machine's real free space: a full CI disk mustn't fail these
      freeDiskSpace: { Int64.max / 2 },
      libraryFileURL: libraryFileURL
    )
  }

  private func run(_ operation: FileUploadOperation, timeout: TimeInterval = 5) async {
    let done = expectation(description: "operation finished")
    let observer = operation.observe(\.isFinished, options: [.initial, .new]) { op, _ in
      if op.isFinished { done.fulfill() }
    }
    operation.start()
    await fulfillment(of: [done], timeout: timeout)
    observer.invalidate()
  }

  private func savedState() async -> MultipartUploadState? {
    let task = await repository.getNextTask(for: TaskQueueKey.uploadFile)
    return task.map { MultipartUploadState(parameters: $0.parameters) }
  }

  // MARK: - Plan

  func testPlan_splitsTheFileIntoFixedSizeParts() {
    let plan = MultipartUploadPlan(fileSize: 10, partSize: 4)
    XCTAssertEqual(plan.partCount, 3)
    XCTAssertEqual(plan.range(of: 1), 0..<4)
    XCTAssertEqual(plan.range(of: 3), 8..<10)
    XCTAssertEqual(plan.size(of: 3), 2)
    XCTAssertEqual(plan.pendingParts(done: [1], active: [2]), [3])

    let big = MultipartUploadPlan(fileSize: 6_000_000_000, partSize: FileUploadOperation.partSize)
    XCTAssertEqual(big.partCount, 90)
    XCTAssertEqual(
      big.openSlots(window: 8, active: 3, freeBytes: Int64(10) * 1024 * 1024 * 1024, reserve: 0),
      5
    )
    // Room for two parts beyond the reserve
    XCTAssertEqual(
      big.openSlots(window: 8, active: 0, freeBytes: Int64(FileUploadOperation.partSize) * 2 + 100, reserve: 100),
      2
    )
    XCTAssertEqual(big.openSlots(window: 8, active: 8, freeBytes: .max / 2, reserve: 0), 0)
  }

  func testPartOutcome_followsS3sAnswers() {
    XCTAssertEqual(FileUploadOperation.outcome(statusCode: 200, error: nil), .uploaded)
    XCTAssertEqual(FileUploadOperation.outcome(statusCode: 403, error: nil), .resend)
    XCTAssertEqual(FileUploadOperation.outcome(statusCode: 404, error: nil), .uploadGone)
    XCTAssertEqual(FileUploadOperation.outcome(statusCode: 500, error: nil), .failed)
    XCTAssertEqual(FileUploadOperation.outcome(statusCode: 400, error: nil), .failed)
    XCTAssertEqual(FileUploadOperation.outcome(statusCode: nil, error: URLError(.timedOut)), .failed)
    XCTAssertEqual(FileUploadOperation.outcome(statusCode: nil, error: URLError(.cancelled)), .resend)
  }

  // MARK: - Engine

  func testFreshUpload_startsSendsEveryPartInOrder_andCompletes() async throws {
    try await storeTask()
    let operation = makeOperation()

    await run(operation)

    XCTAssertTrue(operation.didSucceed)
    XCTAssertTrue(operation.uploadCompleted)
    XCTAssertEqual(server.calls(to: "/v1/library/upload/start"), 1)
    XCTAssertEqual(server.calls(to: "/v1/library/upload/complete"), 1)
    XCTAssertEqual(transport.startedParts, [1, 2, 3])
    XCTAssertEqual(transport.sentBytes, [1: "0123", 2: "4567", 3: "89"])
    XCTAssertEqual(server.lastComplete?["partCount"] as? Int, 3)
    XCTAssertEqual(server.lastComplete?["fileSize"] as? Int64, 10)
    let state = await savedState()
    XCTAssertEqual(state?.uploadId, "upload-1")
    XCTAssertEqual(state?.fileSize, 10)
    // Parts and the temp hard link are cleaned up
    XCTAssertFalse(FileManager.default.fileExists(atPath: FileUploadOperation.partsDirectory(for: uuid).path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
  }

  /// A relaunch resumes the same upload: nothing S3 has or the session is still sending
  /// is sent again
  func testResume_skipsPartsS3HasAndPartsStillInFlight() async throws {
    try await storeTask()
    server.uploadedParts = [1]
    transport.inFlightAtLaunch = [2]
    let operation = makeOperation(state: .init(uploadId: "upload-1", partSize: 4, fileSize: 10, restartCount: 0))

    await run(operation)

    XCTAssertTrue(operation.uploadCompleted)
    XCTAssertEqual(server.calls(to: "/v1/library/upload/start"), 0)
    XCTAssertEqual(transport.startedParts, [3])
  }

  func testExpiredPartURL_isResentWithAFreshURL_notRestarted() async throws {
    try await storeTask()
    transport.statusByAttempt = [2: [403, 200]]
    let operation = makeOperation()

    await run(operation)

    XCTAssertTrue(operation.uploadCompleted)
    XCTAssertEqual(transport.startedParts, [1, 2, 3, 2])
    XCTAssertEqual(server.calls(to: "/v1/library/upload/start"), 1)
  }

  func testMissingPartsAtComplete_areResent_thenCompleted() async throws {
    try await storeTask()
    server.completeErrors = [coded("parts_missing", status: 409)]
    server.uploadedPartsAfterMissing = [1, 3]
    let operation = makeOperation()

    await run(operation)

    XCTAssertTrue(operation.uploadCompleted)
    XCTAssertEqual(server.calls(to: "/v1/library/upload/complete"), 2)
    XCTAssertEqual(transport.startedParts, [1, 2, 3, 2])
    XCTAssertEqual(server.calls(to: "/v1/library/upload/start"), 1)
  }

  func testLostUpload_startsAgain_countingTheRestart() async throws {
    try await storeTask()
    server.listErrors = [coded("upload_not_found", status: 409)]
    let operation = makeOperation(state: .init(uploadId: "stale", partSize: 4, fileSize: 10, restartCount: 0))

    await run(operation)

    XCTAssertTrue(operation.uploadCompleted)
    XCTAssertEqual(server.calls(to: "/v1/library/upload/start"), 1)
    let state = await savedState()
    XCTAssertEqual(state?.restartCount, 1)
    XCTAssertEqual(state?.uploadId, "upload-1")
  }

  /// Past the budget the server's answer is the failure, so the queue parks the task
  func testRestartBudget_whenExhausted_failsWithTheServersCode() async throws {
    try await storeTask()
    server.completeErrors = Array(repeating: coded("invalid_parts", status: 422), count: 10)
    let operation = makeOperation()

    await run(operation)

    XCTAssertFalse(operation.didSucceed)
    XCTAssertEqual(SyncFailurePolicy.codedFailure(operation.error)?.code, "invalid_parts")
    XCTAssertEqual(server.calls(to: "/v1/library/upload/start"), FileUploadOperation.restartBudget + 1)
    XCTAssertEqual(
      SyncFailurePolicy.action(for: operation.error, jobType: .uploadFile, parkingEnabled: true),
      .park(.task)
    )
    // A Retry starts over: the dead upload is forgotten and the budget reset
    let state = await savedState()
    XCTAssertNil(state?.uploadId)
    XCTAssertEqual(state?.restartCount, 0)
  }

  func testAlreadyInS3_finishesWithoutSendingParts() async throws {
    try await storeTask()
    server.startStatus = "exists"
    let operation = makeOperation()

    await run(operation)

    XCTAssertTrue(operation.uploadCompleted)
    XCTAssertTrue(transport.startedParts.isEmpty)
    XCTAssertEqual(server.calls(to: "/v1/library/upload/complete"), 0)
  }

  func testOverTheSizeLimit_isRefusedBeforeTheServer_andParks() async throws {
    try await storeTask()
    let handle = try FileHandle(forWritingTo: fileURL)
    try handle.truncate(atOffset: UInt64(FileUploadOperation.maxFileSize) + 1)
    try handle.close()
    let operation = makeOperation()

    await run(operation)

    XCTAssertFalse(operation.didSucceed)
    XCTAssertEqual(operation.error as? UploadFileError, .fileTooLarge)
    XCTAssertEqual(server.totalCalls, 0)
    let failure = SyncFailurePolicy.codedFailure(operation.error)
    XCTAssertEqual(failure?.code, "file_too_large")
    XCTAssertNil(failure?.httpStatus)
    XCTAssertEqual(
      SyncFailurePolicy.action(for: operation.error, jobType: .uploadFile, parkingEnabled: true),
      .park(.task)
    )
  }

  /// Nothing to upload: the task is consumed, not retried forever
  func testMissingSourceFile_isConsumed() async throws {
    try await storeTask()
    try FileManager.default.removeItem(at: fileURL)
    let operation = makeOperation()

    await run(operation)

    XCTAssertTrue(operation.didSucceed)
    XCTAssertFalse(operation.uploadCompleted)
    XCTAssertEqual(server.totalCalls, 0)
  }

  func testTaskClearedMidUpload_stopsTheUpload() async throws {
    // Never stored: saving the state after `start` finds no task (a logout cleared it)
    let operation = makeOperation()

    await run(operation)

    XCTAssertFalse(operation.didSucceed)
    // Stopped by the failed save after `start`, not by an earlier failure
    XCTAssertEqual(server.calls(to: "/v1/library/upload/start"), 1)
    guard case .cancelledTask = operation.error as? BookPlayerError else {
      return XCTFail("expected the cleared task to cancel the upload, got \(String(describing: operation.error))")
    }
    XCTAssertTrue(transport.startedParts.isEmpty)
  }

  /// iOS purged the temp link, or the user moved the book: found again by uuid, uploaded,
  /// and the real library file is never deleted
  func testPurgedTempLink_uploadsTheLibraryFileFoundByUuid() async throws {
    try await storeTask()
    let libraryFile = FileManager.default.temporaryDirectory
      .appendingPathComponent("library-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: libraryFile, withIntermediateDirectories: true)
    let bookURL = libraryFile.appendingPathComponent("Book.m4b")
    try Data("abcdefghij".utf8).write(to: bookURL)
    defer { try? FileManager.default.removeItem(at: libraryFile) }
    try FileManager.default.removeItem(at: fileURL)
    let operation = makeOperation(libraryFileURL: { uuid in uuid == "book-uuid" ? bookURL : nil })

    await run(operation)

    XCTAssertTrue(operation.uploadCompleted)
    XCTAssertEqual(transport.sentBytes, [1: "abcd", 2: "efgh", 3: "ij"])
    XCTAssertTrue(FileManager.default.fileExists(atPath: bookURL.path), "the user's file must survive")
  }

  /// Turning cellular on or off moves the parts in flight to the session that now applies
  func testCellularSettingChange_resendsThePartsInFlight() async throws {
    try await storeTask()
    let key = Constants.UserDefaults.allowCellularData
    let original = UserDefaults.standard.bool(forKey: key)
    defer { UserDefaults.standard.set(original, forKey: key) }
    transport.holdParts = true
    let operation = makeOperation()
    let done = expectation(description: "operation finished")
    let observer = operation.observe(\.isFinished, options: [.initial, .new]) { op, _ in
      if op.isFinished { done.fulfill() }
    }
    operation.start()
    try await transport.waitForStartedParts(3)

    transport.holdParts = false
    UserDefaults.standard.set(!original, forKey: key)

    await fulfillment(of: [done], timeout: 5)
    observer.invalidate()
    XCTAssertTrue(operation.uploadCompleted)
    XCTAssertEqual(transport.startedParts.sorted(), [1, 1, 2, 2, 3, 3])
  }

  func testCancel_cancelsTheParts() async throws {
    try await storeTask()
    transport.holdParts = true
    let operation = makeOperation()
    operation.start()
    try await transport.waitForStartedParts(3)

    operation.cancel()

    try await transport.waitForCancel()
    XCTAssertFalse(operation.didSucceed)
    XCTAssertTrue(operation.isFinished)
    // The run removes the parts and the link once its loop has stopped
    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline,
          FileManager.default.fileExists(atPath: FileUploadOperation.partsDirectory(for: uuid).path) {
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: FileUploadOperation.partsDirectory(for: uuid).path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
  }

  // MARK: - Settle (background wakes)

  /// Settles once the parts delivered so far are handled and the window refilled
  func testSettle_returnsAfterTheTopUp() async throws {
    try await storeTask()
    transport.holdParts = true
    let operation = makeOperation()
    operation.start()
    try await transport.waitForStartedParts(3)

    let stillRunning = await operation.settle()

    XCTAssertTrue(stillRunning)
    XCTAssertEqual(transport.startedParts, [1, 2, 3])
    XCTAssertFalse(operation.isFinished)
    operation.cancel()
  }

  /// Asked before the engine's loop exists (it's still starting the upload): it settles
  /// after the first top-up
  func testSettle_beforeTheLoopStarts_waitsForTheFirstTopUp() async throws {
    try await storeTask()
    transport.holdParts = true
    let operation = makeOperation()
    let settled = Task { await operation.settle() }
    try await Task.sleep(for: .milliseconds(50))

    operation.start()
    let stillRunning = await settled.value

    XCTAssertTrue(stillRunning)
    XCTAssertEqual(transport.startedParts, [1, 2, 3])
    operation.cancel()
  }

  /// The upload ends while a wake waits: it reports done (so the queue waits for the lane's
  /// next upload), and the operation already reads as finished
  func testSettle_whenTheUploadEndsFirst_reportsItDone() async throws {
    try await storeTask()
    server.startStatus = "exists"
    let operation = makeOperation()
    let settled = Task { await operation.settle() }
    try await Task.sleep(for: .milliseconds(50))

    operation.start()
    let stillRunning = await settled.value

    XCTAssertFalse(stillRunning)
    XCTAssertTrue(operation.isFinished)
  }

  func testSettle_afterTheUploadFinished_returnsRightAway() async throws {
    try await storeTask()
    let operation = makeOperation()
    await run(operation)

    let stillRunning = await operation.settle()

    XCTAssertFalse(stillRunning)
    XCTAssertTrue(operation.uploadCompleted)
  }

  private func coded(_ code: String, status: Int) -> BookPlayerError {
    .networkErrorWithCode(message: code, code: code, status: status)
  }
}

// MARK: - Fakes

/// Answers the /upload/* routes like the server would, with scripted failures
private final class ScriptedUploadServer: NetworkClientMock, @unchecked Sendable {
  private let lock = NSLock()
  private var callsByPath = [String: Int]()
  var startStatus = "started"
  var uploadedParts = [Int]()
  /// What GET /parts answers after a parts_missing (S3's real list at that point)
  var uploadedPartsAfterMissing: [Int]?
  var listErrors = [Error]()
  var completeErrors = [Error]()
  private(set) var lastComplete: [String: Any]?
  private var uploadCount = 0

  init() { super.init(mockedResponse: Empty()) }

  var totalCalls: Int { lock.withLock { callsByPath.values.reduce(0, +) } }

  func calls(to path: String) -> Int { lock.withLock { callsByPath[path, default: 0] } }

  override func request<T: Decodable>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T {
    let json: String = try lock.withLock {
      callsByPath[path, default: 0] += 1
      switch (path, method) {
      case ("/v1/library/upload/start", _):
        uploadCount += 1
        uploadedParts = []
        return startStatus == "exists"
          ? #"{"status":"exists"}"#
          : #"{"status":"started","uploadId":"upload-\#(uploadCount)","partSize":4,"partCount":3}"#
      case ("/v1/library/upload/parts", .get):
        if !listErrors.isEmpty { throw listErrors.removeFirst() }
        let parts = uploadedParts.map { #"{"partNumber":\#($0),"size":4}"# }.joined(separator: ",")
        return #"{"parts":[\#(parts)]}"#
      case ("/v1/library/upload/parts", .post):
        let numbers = parameters?["partNumbers"] as? [Int] ?? []
        let parts = numbers
          .map { #"{"partNumber":\#($0),"url":"https://s3.test/p\#($0)","expiresAt":1790000000}"# }
          .joined(separator: ",")
        return #"{"parts":[\#(parts)]}"#
      case ("/v1/library/upload/complete", _):
        lastComplete = parameters
        if !completeErrors.isEmpty {
          let error = completeErrors.removeFirst()
          if let missingList = uploadedPartsAfterMissing {
            uploadedParts = missingList
          }
          throw error
        }
        return #"{"synced":true}"#
      default:
        return "{}"
      }
    }
    return try JSONDecoder().decode(T.self, from: Data(json.utf8))
  }

  /// A part the transport finished with 2xx is now in S3
  func recordUploaded(_ partNumber: Int) {
    lock.withLock {
      if !uploadedParts.contains(partNumber) { uploadedParts.append(partNumber) }
    }
  }
}

/// Finishes each started part on its own, per a scripted status sequence
private final class FakePartTransport: PartUploadTransport, @unchecked Sendable {
  private let lock = NSLock()
  private var handler: ((PartUploadEvent) -> Void)?
  private var _startedParts = [Int]()
  private var _sentBytes = [Int: String]()
  private var attempts = [Int: Int]()
  private var cancelled = false
  private var held = Set<Int>()
  /// Parts the session is still sending when the operation starts; they finish shortly after
  var inFlightAtLaunch = Set<Int>()
  /// Per part: S3's answer on each attempt (default 200)
  var statusByAttempt = [Int: [Int]]()
  /// Parts never finish on their own (to test cancel)
  private var _holdParts = false
  var holdParts: Bool {
    get { lock.withLock { _holdParts } }
    set { lock.withLock { _holdParts = newValue } }
  }

  var startedParts: [Int] { lock.withLock { _startedParts } }
  var sentBytes: [Int: String] { lock.withLock { _sentBytes } }

  func activePartNumbers(for uuid: String, uploadId: String) async -> Set<Int> {
    let pending = lock.withLock { () -> Set<Int> in
      let parts = inFlightAtLaunch
      inFlightAtLaunch = []
      return parts
    }
    for part in pending {
      finish(part, status: 200, after: 0.05)
    }
    return pending
  }

  func startPart(uuid: String, uploadId: String, partNumber: Int, file: URL, url: URL) {
    let status: Int = lock.withLock {
      _startedParts.append(partNumber)
      _sentBytes[partNumber] = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
      let attempt = attempts[partNumber, default: 0]
      attempts[partNumber] = attempt + 1
      let script = statusByAttempt[partNumber] ?? []
      return attempt < script.count ? script[attempt] : 200
    }
    guard !holdParts else {
      lock.withLock { held.insert(partNumber) }
      return
    }
    finish(partNumber, status: status, after: 0.01)
  }

  /// Held parts come back cancelled, like a session's tasks do
  func cancelParts(for uuid: String) async {
    let parts = lock.withLock { () -> Set<Int> in
      cancelled = true
      let parts = held
      held = []
      return parts
    }
    for part in parts {
      DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) { [weak self] in
        let handler = self?.lock.withLock { self?.handler }
        handler?(.finished(partNumber: part, statusCode: nil, error: URLError(.cancelled)))
      }
    }
  }

  func subscribe(uuid: String, uploadId: String, handler: @escaping (PartUploadEvent) -> Void) -> AnyCancellable {
    lock.withLock { self.handler = handler }
    return AnyCancellable { [weak self] in
      self?.lock.withLock { self?.handler = nil }
    }
  }

  /// Set by the test so a 2xx lands in the scripted server's part list
  weak var server: AnyObject?

  private func finish(_ partNumber: Int, status: Int, after delay: TimeInterval) {
    DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let self else { return }
      if (200...299).contains(status) {
        (self.server as? ScriptedUploadServer)?.recordUploaded(partNumber)
      }
      let handler = self.lock.withLock { self.handler }
      handler?(.finished(partNumber: partNumber, statusCode: status, error: nil))
    }
  }

  func waitForStartedParts(_ count: Int, timeout: TimeInterval = 3) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if startedParts.count >= count { return }
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTFail("timed out waiting for \(count) started parts")
  }

  func waitForCancel(timeout: TimeInterval = 3) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if lock.withLock({ cancelled }) { return }
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTFail("timed out waiting for the parts to be cancelled")
  }
}
