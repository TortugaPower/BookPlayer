//
//  UploadContinuationTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BackgroundTasks
import Combine
import Foundation
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

private final class FakeContinuedTask: ContinuedUploadTask {
  let progress = Progress(totalUnitCount: 0)
  var expirationHandler: (() -> Void)?
  private(set) var titles = [(String, String)]()
  private(set) var completions = [Bool]()

  func updateTitle(_ title: String, subtitle: String) { titles.append((title, subtitle)) }
  func setTaskCompleted(success: Bool) { completions.append(success) }
}

@MainActor
final class UploadContinuationTests: XCTestCase {
  private func book(_ uuid: String, _ name: String, _ size: Int64) -> PendingBookUpload {
    PendingBookUpload(uuid: uuid, relativePath: "Folder/\(name)", fileSize: size)
  }

  // MARK: - Progress

  func testProgress_countsBytesPositionAndTheCurrentFile() {
    var progress = UploadContinuationProgress()
    progress.update(waiting: [book("a", "A.m4b", 100), book("b", "B.m4b", 300)])

    XCTAssertEqual(progress.position.index, 1)
    XCTAssertEqual(progress.position.count, 2)
    XCTAssertEqual(progress.currentFileName, "A.m4b", "the next one waiting before any upload runs")
    XCTAssertEqual(progress.totalBytes, 400)
    XCTAssertEqual(progress.completedBytes, 0)

    progress.updateProgress(uuid: "a", fraction: 0.5)
    XCTAssertEqual(progress.completedBytes, 50)

    // A finished; B is being sent
    progress.update(waiting: [book("b", "B.m4b", 300)])
    progress.updateProgress(uuid: "b", fraction: 0.1)
    XCTAssertEqual(progress.position.index, 2)
    XCTAssertEqual(progress.currentFileName, "B.m4b")
    XCTAssertEqual(progress.completedBytes, 130)
    XCTAssertFalse(progress.isFinished)

    progress.update(waiting: [])
    XCTAssertTrue(progress.isFinished)
    XCTAssertEqual(progress.completedBytes, 400)
  }

  /// Books queued mid-run join the count instead of starting a new one
  func testProgress_growsWhenBooksAreQueuedMidRun() {
    var progress = UploadContinuationProgress()
    progress.update(waiting: [book("a", "A.m4b", 100)])
    progress.update(waiting: [])
    progress.update(waiting: [book("c", "C.m4b", 50)])

    XCTAssertEqual(progress.position.index, 2)
    XCTAssertEqual(progress.position.count, 2)
    XCTAssertEqual(progress.totalBytes, 150)
    XCTAssertEqual(progress.currentFileName, "C.m4b")
  }

  func testSubtitle_prefixesThePositionToTheFileName() {
    var progress = UploadContinuationProgress()
    progress.update(waiting: [book("a", "A.m4b", 1), book("b", "B.m4b", 1), book("c", "C.m4b", 1)])
    progress.update(waiting: [book("b", "B.m4b", 1), book("c", "C.m4b", 1)])

    XCTAssertEqual(UploadContinuationController.subtitle(for: progress), "(2 / 3) B.m4b")
    XCTAssertEqual(UploadContinuationController.title, "Uploading files")
  }

  // MARK: - Controller

  private var pending = [PendingBookUpload]()
  private var parkedCount = 0
  private var submitted = [BGTaskRequest]()
  private var submitError: Error?
  private var canUpload = true
  private var networkAllows = true
  private var foreground = true
  private var requestPending = true
  private let changes = PassthroughSubject<QueueCounts, Never>()

  private func dependencies() -> UploadContinuationController.Dependencies {
    .init(
      canUpload: { [unowned self] in self.canUpload },
      networkAllowsUploads: { [unowned self] in self.networkAllows },
      isForeground: { [unowned self] in self.foreground },
      pendingUploads: { [unowned self] in PendingBookUploads(books: self.pending, parkedCount: self.parkedCount) },
      submit: { [unowned self] request in
        if let submitError = self.submitError { throw submitError }
        self.submitted.append(request)
      },
      hasPendingRequest: { [unowned self] in self.requestPending },
      queueChanges: { [unowned self] in self.changes.eraseToAnyPublisher() },
      confirmEmptyAfter: .milliseconds(50)
    )
  }

  private func makeController() -> UploadContinuationController {
    let controller = UploadContinuationController()
    controller.setup(dependencies: dependencies())
    return controller
  }

  private func waitUntil(_ timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline, !condition() {
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  func testSubmit_whenBooksWait_submitsOneRequestAndStarts() async {
    pending = [book("a", "A.m4b", 100)]
    let controller = makeController()

    await controller.submitIfNeeded()
    await controller.submitIfNeeded()

    XCTAssertEqual(submitted.count, 1, "one continued task covers the whole queue")
    XCTAssertEqual(submitted.first?.identifier, UploadContinuationController.identifier)
    XCTAssertEqual(controller.state, .starting)
  }

  func testSubmit_isHeldBackWhenItCantHelp() async {
    let controller = makeController()

    // Nothing waiting
    await controller.submitIfNeeded()
    pending = [book("a", "A.m4b", 100)]
    // No S3 access / sync off
    canUpload = false
    await controller.submitIfNeeded()
    canUpload = true
    // Wi-Fi only, on cellular
    networkAllows = false
    await controller.submitIfNeeded()
    networkAllows = true
    // iOS only accepts it from the foreground
    foreground = false
    await controller.submitIfNeeded()

    XCTAssertTrue(submitted.isEmpty)
    XCTAssertEqual(controller.state, .idle)
  }

  func testSubmit_refused_returnsToIdle() async {
    pending = [book("a", "A.m4b", 100)]
    submitError = URLError(.unknown)
    let controller = makeController()

    await controller.submitIfNeeded()

    XCTAssertEqual(controller.state, .idle)
  }

  /// iOS accepted a request but dropped it: the next queued books submit again
  func testSubmit_afterIOSDroppedTheRequest_submitsAgain() async {
    pending = [book("a", "A.m4b", 100)]
    let controller = makeController()
    await controller.submitIfNeeded()
    requestPending = false

    await controller.submitIfNeeded()

    XCTAssertEqual(submitted.count, 2)
    XCTAssertEqual(controller.state, .starting)
  }

  /// An import (or the first sync after signing in) queues books: that alone submits it
  func testQueuedBooks_submitTheTask() async throws {
    pending = [book("a", "A.m4b", 100)]
    let controller = makeController()

    NotificationCenter.default.post(name: .bookUploadsQueued, object: nil)

    try await waitUntil { !submitted.isEmpty }
    XCTAssertEqual(submitted.count, 1)
    XCTAssertEqual(controller.state, .starting)
  }

  func testRunningTask_reportsProgressAndEndsWhenTheQueueEmpties() async throws {
    pending = [book("a", "A.m4b", 100), book("b", "B.m4b", 100)]
    let controller = makeController()
    let task = FakeContinuedTask()

    controller.attach(task)
    try await waitUntil { !task.titles.isEmpty }
    XCTAssertEqual(controller.state, .running)
    XCTAssertEqual(task.titles.last?.1, "(1 / 2) A.m4b")
    XCTAssertEqual(task.progress.totalUnitCount, 200)

    NotificationCenter.default.post(
      name: .uploadProgressUpdated,
      object: nil,
      userInfo: ["uuid": "a", "relativePath": "Folder/A.m4b", "progress": 0.5]
    )
    try await waitUntil { task.progress.completedUnitCount == 50 }
    XCTAssertEqual(task.progress.completedUnitCount, 50)

    pending = [book("b", "B.m4b", 100)]
    changes.send(QueueCounts(byQueueKey: [TaskQueueKey.uploadFile: 1]))
    try await waitUntil { task.titles.last?.1 == "(2 / 2) B.m4b" }
    XCTAssertEqual(task.titles.last?.1, "(2 / 2) B.m4b")

    pending = []
    changes.send(QueueCounts())
    try await waitUntil { !task.completions.isEmpty }
    XCTAssertEqual(task.completions, [true])
    XCTAssertEqual(controller.state, .idle)
  }

  /// A book moving between lanes looks absent for a moment: that's not the end
  func testRunningTask_momentarilyEmptyQueue_keepsRunning() async throws {
    pending = [book("a", "A.m4b", 100)]
    let controller = makeController()
    let task = FakeContinuedTask()
    controller.attach(task)
    try await waitUntil { !task.titles.isEmpty }

    pending = []
    changes.send(QueueCounts())
    try await Task.sleep(for: .milliseconds(20))
    pending = [book("a", "A.m4b", 100)]
    try await Task.sleep(for: .milliseconds(150))

    XCTAssertTrue(task.completions.isEmpty)
    XCTAssertEqual(controller.state, .running)
  }

  func testRunningTask_withOnlyParkedUploadsLeft_endsUnsuccessful() async throws {
    pending = []
    parkedCount = 1
    let controller = makeController()
    let task = FakeContinuedTask()

    controller.attach(task)

    try await waitUntil { !task.completions.isEmpty }
    XCTAssertEqual(task.completions, [false])
  }

  /// Books stuck behind a blocked lane (or an account-level pause) wait on the user: the
  /// run ends instead of holding the Live Activity until iOS expires it
  func testRunningTask_behindABlockedLane_ends() async throws {
    pending = [PendingBookUpload(uuid: "a", relativePath: "A.m4b", fileSize: 1, queueKey: TaskQueueKey.sync)]
    let controller = makeController()
    let task = FakeContinuedTask()
    controller.attach(task)
    try await waitUntil { !task.titles.isEmpty }

    changes.send(QueueCounts(byQueueKey: [TaskQueueKey.sync: 2], pausedByQueueKey: [TaskQueueKey.sync: 1], blockedQueueKeys: [TaskQueueKey.sync]))

    try await waitUntil { !task.completions.isEmpty }
    XCTAssertEqual(task.completions, [false])
  }

  /// iOS launched it before the services were up (a cold launch into the task): it's held,
  /// not failed, and runs once they are
  func testTaskLaunchedBeforeSetup_isHeldUntilTheServicesExist() async throws {
    pending = [book("a", "A.m4b", 100)]
    let controller = UploadContinuationController()
    let task = FakeContinuedTask()

    controller.attach(task)
    XCTAssertTrue(task.completions.isEmpty)
    XCTAssertNotNil(task.expirationHandler, "expiry is answered even while held")

    controller.setup(dependencies: dependencies())
    try await waitUntil { !task.titles.isEmpty }
    XCTAssertEqual(controller.state, .running)
  }

  /// Expired while held (the services never came up in time): not attached afterwards
  func testTaskExpiredWhileHeld_isNotAttachedLater() async throws {
    pending = [book("a", "A.m4b", 100)]
    let controller = UploadContinuationController()
    let task = FakeContinuedTask()
    controller.attach(task)

    task.expirationHandler?()
    try await Task.sleep(for: .milliseconds(50))
    controller.setup(dependencies: dependencies())
    try await Task.sleep(for: .milliseconds(100))

    XCTAssertEqual(task.completions, [false])
    XCTAssertEqual(controller.state, .idle)
    XCTAssertTrue(task.titles.isEmpty)
  }

  /// Every waiting book sits behind a paused lane: no Live Activity that fails at once
  func testSubmit_behindABlockedLane_isHeldBack() async throws {
    pending = [PendingBookUpload(uuid: "a", relativePath: "A.m4b", fileSize: 1, queueKey: TaskQueueKey.sync)]
    let controller = makeController()
    changes.send(QueueCounts(byQueueKey: [TaskQueueKey.sync: 2], pausedByQueueKey: [TaskQueueKey.sync: 1], blockedQueueKeys: [TaskQueueKey.sync]))
    try await Task.sleep(for: .milliseconds(50))

    await controller.submitIfNeeded()

    XCTAssertTrue(submitted.isEmpty)
    XCTAssertEqual(controller.state, .idle)
  }

  /// Expiry (and a cancel from the Live Activity) is answered once, right in the handler
  func testExpiration_completesTheTaskOnce() async throws {
    pending = [book("a", "A.m4b", 100)]
    let controller = makeController()
    let task = FakeContinuedTask()
    controller.attach(task)
    try await waitUntil { !task.titles.isEmpty }

    task.expirationHandler?()
    XCTAssertEqual(task.completions, [false])
    try await waitUntil { controller.state == .idle }

    pending = []
    changes.send(QueueCounts())
    try await Task.sleep(for: .milliseconds(150))
    XCTAssertEqual(task.completions, [false], "not completed a second time")
  }
}
