//
//  MissingItemsPassTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftData
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// The missing-items pass (bookplayer-api docs/multipart-uploads.md): the first sync's
/// registration step, then again on LITE → PRO and weekly. It works by uuid, never by path,
/// so a path that went stale on this device can't move anything back on the server.
/// Main actor: the tests use the main-queue view context (see LibraryServiceTests).
@MainActor
final class MissingItemsPassTests: XCTestCase {
  /// Answers `/status` from its script and records every request
  private final class StatusClient: NetworkClientMock, @unchecked Sendable {
    private let lock = NSLock()
    private var _statusRequests = [[String]]()
    private var _matchRequests = [[String: String]]()
    private var _answer: (unknown: [String], unsynced: [String]) = ([], [])
    private var _conflicts = [[String: String]]()
    private var _failsStatus = false
    private var _rootContent = [[String: Any]]()
    private var _onStatus: (() async -> Void)?

    var statusRequests: [[String]] { lock.withLock { _statusRequests } }
    var matchRequests: [[String: String]] { lock.withLock { _matchRequests } }

    /// `/uuids` answers these conflicts: local uuid → the server's
    func conflict(_ localUuid: String, serverUuid: String) {
      lock.withLock { _conflicts.append(["key": localUuid, "uuid": serverUuid]) }
    }

    init() {
      super.init(mockedResponse: Empty())
    }

    func answer(unknown: [String] = [], unsynced: [String] = []) {
      lock.withLock { _answer = (unknown, unsynced) }
    }

    func failStatus() {
      lock.withLock { _failsStatus = true }
    }

    func setRootContent(_ content: [[String: Any]]) {
      lock.withLock { _rootContent = content }
    }

    /// Runs while the server "answers" `/status`
    func onStatus(_ action: @escaping () async -> Void) {
      lock.withLock { _onStatus = action }
    }

    override func request<T: Decodable>(
      path: String,
      method: HTTPMethod,
      parameters: [String: Any]?
    ) async throws -> T {
      if path == "/v1/library/status", let action = lock.withLock({ _onStatus }) {
        await action()
      }
      let object: Any = try lock.withLock {
        switch (path, method) {
        case ("/v1/library/status", _):
          _statusRequests.append(parameters?["uuids"] as? [String] ?? [])
          if _failsStatus { throw URLError(.notConnectedToInternet) }
          return ["unknown": _answer.unknown, "unsynced": _answer.unsynced]
        case ("/v1/library/uuids", _):
          _matchRequests.append(parameters?["items"] as? [String: String] ?? [:])
          return ["applied": [String](), "conflicts": _conflicts]
        case ("/v1/library", .get):
          return ["content": _rootContent]
        default:
          return [String: Any]()
        }
      }
      return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }
  }

  /// Its own suite: the test host's SyncService works on `.standard`
  private var defaults: UserDefaults!
  private var defaultsSuite = ""

  private var tasksDataManager: TasksDataManager!
  private var repository: SyncQueueRepository!
  private var dataManager: DataManager!
  private var libraryService: LibraryService!
  private var queue: SyncQueueService!
  private var client: StatusClient!
  private var account: AccountServiceMock!
  private var sync: SyncService!

  override func setUpWithError() throws {
    defaultsSuite = "MissingItemsPassTests-\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: defaultsSuite)

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
    tasksDataManager = TasksDataManager(container: try ModelContainer(for: schema, configurations: config))
    repository = SyncQueueRepository(tasksDataManager: tasksDataManager)

    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: AudioMetadataService())
    _ = libraryService.getLibrary()

    client = StatusClient()
    queue = SyncQueueService(maxConcurrentTasks: 1)
    queue.taskContainer = repository
    queue.tasksDataManager = tasksDataManager
    // Conflicts rewrite the library's uuids through it
    queue.dataManager = dataManager
    queue.libraryService = libraryService
    queue.accessPolicy = [.uploadFile: true, .externalUpdate: true]
    queue.networkClient = client
    account = AccountServiceMock(account: nil)
    sync = makeSyncService(runsMissingItemsPass: true)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: defaultsSuite)
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    sync = nil
    queue = nil
    repository = nil
    tasksDataManager = nil
    super.tearDown()
  }

  private func makeSyncService(runsMissingItemsPass: Bool) -> SyncService {
    let service = SyncService()
    service.setup(
      isActive: true,
      libraryService: libraryService,
      accountService: account,
      syncQueueService: queue,
      client: client,
      runsMissingItemsPass: runsMissingItemsPass,
      userDefaults: defaults
    )
    // Hold what the pass queues, for the assertions
    queue.setServerLanesEnabled(false)
    return service
  }

  /// A book at the library root, its file in Processed
  private func book(_ title: String) -> Book {
    let book = StubFactory.book(dataManager: dataManager, title: title, duration: 100)
    dataManager.saveContext()
    return book
  }

  private func queueUploadFile(for book: Book, parked: Bool = false) async throws {
    let id = UUID().uuidString
    try await repository.storeTask(parameters: [
      "id": id,
      "jobType": SyncJobType.uploadFile.rawValue,
      "queueKey": TaskQueueKey.uploadFile,
      "uuid": book.uuid,
      "relativePath": book.relativePath,
      "filePath": DataManager.getProcessedFolderURL().appendingPathComponent(book.relativePath).absoluteString,
    ])
    if parked {
      await repository.park(
        taskId: id,
        pause: TaskPause(scope: .task, errorCode: "invalid_parts", message: "m", httpStatus: 422, pausedAt: Date())
      )
    }
  }

  private func syncLane() async -> [SyncTask] {
    await repository.getAllTasksWithParams(in: TaskQueueKey.sync)
  }

  private func uploadLane() async -> [SyncTask] {
    await repository.getAllTasksWithParams(in: TaskQueueKey.uploadFile)
  }

  private func waitUntil(timeout: TimeInterval = 3, _ condition: () async -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if await condition() { return }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTFail("timed out")
  }
}

// MARK: - The pass

extension MissingItemsPassTests {
  /// Items the server never saw are matched by path first (a legacy row at the same path
  /// would otherwise keep the server's uuid), then registered like an import, parents first
  func testPass_matchesThenRegistersUnknownItems_parentsFirst() async throws {
    let alpha = book("Alpha")
    let shelf = try libraryService.createFolder(with: "Shelf", inside: nil)
    let inner = try libraryService.createFolder(with: "Inner", inside: shelf.relativePath)
    client.answer(unknown: [inner.uuid, alpha.uuid, shelf.uuid])

    try await sync.runMissingItemsPass(startsContinuedUploads: false)

    XCTAssertEqual(
      client.matchRequests,
      [[alpha.relativePath: alpha.uuid, "Shelf": shelf.uuid, "Shelf/Inner": inner.uuid]]
    )
    let lane = await syncLane()
    XCTAssertEqual(lane.map(\.jobType), [.upload, .upload, .upload])
    XCTAssertEqual(lane.map(\.relativePath), [alpha.relativePath, "Shelf", "Shelf/Inner"])
    let sent = try XCTUnwrap(client.statusRequests.first)
    XCTAssertEqual(Set(sent), [alpha.uuid, shelf.uuid, inner.uuid])
  }

  /// The same file already on the server under another uuid (imported on another device):
  /// this device adopts it BEFORE registering, so every task carries the uuid the server knows
  func testPass_adoptsTheServersUuidBeforeRegistering() async throws {
    let twin = book("Twin")
    let localUuid = twin.uuid
    let serverUuid = UUID().uuidString
    client.answer(unknown: [localUuid])
    client.conflict(localUuid, serverUuid: serverUuid)

    try await sync.runMissingItemsPass(startsContinuedUploads: false)

    let lane = await syncLane()
    XCTAssertEqual(lane.map(\.jobType), [.upload])
    XCTAssertEqual(lane.first?.uuid, serverUuid)
    XCTAssertEqual(lane.first?.parameters["uuid"] as? String, serverUuid)
    let adopted = await libraryService.fetchRelativePath(forUuid: serverUuid)
    XCTAssertEqual(adopted, twin.relativePath)
  }

  /// Two rows sharing a uuid bring its conflict back twice: the first answer is adopted
  func testPass_adoptsTheFirstAnswerForARepeatedConflict() async throws {
    let twin = book("Repeated")
    let localUuid = twin.uuid
    let first = UUID().uuidString
    client.answer(unknown: [localUuid])
    client.conflict(localUuid, serverUuid: first)
    client.conflict(localUuid, serverUuid: UUID().uuidString)

    try await sync.runMissingItemsPass(startsContinuedUploads: false)

    let lane = await syncLane()
    XCTAssertEqual(lane.map(\.uuid), [first])
    let adopted = await libraryService.fetchRelativePath(forUuid: first)
    XCTAssertEqual(adopted, twin.relativePath)
  }

  /// A registered book brings its user bookmarks along, in time order; other kinds stay local
  func testPass_registersUserBookmarksWithTheirBook() async throws {
    let marked = book("Marked")
    _ = libraryService.createBookmark(at: 200, relativePath: marked.relativePath, uuid: marked.uuid, type: .user)
    _ = libraryService.createBookmark(at: 50, relativePath: marked.relativePath, uuid: marked.uuid, type: .user)
    _ = libraryService.createBookmark(at: 120, relativePath: marked.relativePath, uuid: marked.uuid, type: .sleep)
    client.answer(unknown: [marked.uuid])

    try await sync.runMissingItemsPass(startsContinuedUploads: false)

    let lane = await syncLane()
    XCTAssertEqual(lane.map(\.jobType), [.upload, .setBookmark, .setBookmark])
    XCTAssertEqual(lane.dropFirst().compactMap { $0.parameters["time"] as? Double }, [50, 200])
    XCTAssertEqual(Set(lane.map(\.uuid)), [marked.uuid])

    // Read 500 paths per fetch: a book past the first batch still brings its bookmarks
    let markedPath: String = marked.relativePath
    let bookmarks = await libraryService.getUserBookmarks(forItemsAt: (0..<600).map { "missing-\($0)" } + [markedPath])
    XCTAssertEqual(bookmarks[markedPath]?.map { $0.time }, [50, 200])
    XCTAssertEqual(bookmarks.count, 1)
  }

  /// Books the server holds without a file go straight to the upload lane by uuid, never
  /// through a re-registration (a `PUT /` at a stale path would move them back)
  func testPass_queuesFilesOfUnsyncedBooksByUuid_skippingOnesAlreadyQueued() async throws {
    let waiting = book("Waiting")
    let queued = book("Queued")
    try await queueUploadFile(for: queued, parked: true)
    client.answer(unsynced: [waiting.uuid, queued.uuid])

    try await sync.runMissingItemsPass(startsContinuedUploads: false)

    let syncTasks = await syncLane()
    XCTAssertTrue(syncTasks.isEmpty)
    let uploads = await uploadLane()
    XCTAssertEqual(uploads.map(\.uuid).sorted(), [queued.uuid, waiting.uuid].sorted())
    let new = try XCTUnwrap(uploads.first { $0.uuid == waiting.uuid })
    XCTAssertEqual(new.relativePath, waiting.relativePath)
    XCTAssertEqual(
      (new.parameters["filePath"] as? String).flatMap(URL.init(string:))?.path,
      DataManager.getProcessedFolderURL().appendingPathComponent(waiting.relativePath).path
    )
  }

  /// Without S3 access (LITE) there are no files to send: only unknown items are registered
  func testPass_withoutS3Access_onlyRegisters() async throws {
    queue.accessPolicy = [.uploadFile: false, .externalUpdate: true]
    let fresh = book("Fresh")
    let unsynced = book("Unsynced")
    client.answer(unknown: [fresh.uuid], unsynced: [unsynced.uuid])

    try await sync.runMissingItemsPass(startsContinuedUploads: false)

    let lane = await syncLane()
    XCTAssertEqual(lane.map(\.jobType), [.upload])
    let uploads = await uploadLane()
    XCTAssertTrue(uploads.isEmpty)
  }

  /// An item whose upload is queued (here parked) isn't lost: the pass leaves it to that task
  func testPass_leavesAnUnknownItemWithAQueuedUploadAlone() async throws {
    let parked = book("Parked")
    try await queueUploadFile(for: parked, parked: true)
    client.answer(unknown: [parked.uuid])

    try await sync.runMissingItemsPass(startsContinuedUploads: false)

    let lane = await syncLane()
    XCTAssertTrue(lane.isEmpty)
    XCTAssertTrue(client.matchRequests.isEmpty)
  }

  /// A failed read registers nothing and isn't recorded as a run: it's asked again
  func testPass_failedStatus_changesNothing() async throws {
    _ = book("Anything")
    client.failStatus()

    do {
      try await sync.runMissingItemsPass(startsContinuedUploads: true)
      XCTFail("expected the pass to fail")
    } catch {}

    let lane = await syncLane()
    XCTAssertTrue(lane.isEmpty)
    XCTAssertEqual(defaults.double(forKey: Constants.UserDefaults.missingItemsPassLastRun), 0)
  }

  /// Only the first sync and a tier change start the continued task; the weekly run never does
  func testPass_announcesQueuedUploadsOnlyWhenAsked() async throws {
    let first = book("First")
    client.answer(unsynced: [first.uuid])
    let quiet = expectation(forNotification: .bookUploadsQueued, object: nil)
    quiet.isInverted = true
    try await sync.runMissingItemsPass(startsContinuedUploads: false)
    await fulfillment(of: [quiet], timeout: 0.3)

    let second = book("Second")
    client.answer(unsynced: [second.uuid])
    let announced = expectation(forNotification: .bookUploadsQueued, object: nil)
    try await sync.runMissingItemsPass(startsContinuedUploads: true)
    await fulfillment(of: [announced], timeout: 1)
  }

  /// What may go up by uuid: a book, not streamed from a media server, its file on this
  /// device, within the 10 GiB ceiling
  func testMissingFileUpload_takesOnlyBooksThatCanUpload() throws {
    func item(_ path: String, type: SimpleItemType = .book, mediaServer: Bool = false) throws -> SyncableItem {
      let resources = mediaServer
        ? #","externalResources":[{"providerName":"jellyfin","providerId":"jf-1","syncStatus":"stream"}]"#
        : ""
      let json = #"{"relativePath":"\#(path)","originalFileName":"\#(path)","title":"t","isFinished":false,"type":\#(type.rawValue),"uuid":"u-\#(path)"\#(resources)}"#
      return try JSONDecoder().decode(SyncableItem.self, from: Data(json.utf8))
    }
    let processed = DataManager.getProcessedFolderURL()
    try FileManager.default.createDirectory(at: processed, withIntermediateDirectories: true)
    for name in ["ok.m4b", "stream.m4b", "huge.m4b"] {
      FileManager.default.createFile(atPath: processed.appendingPathComponent(name).path, contents: Data("x".utf8))
    }
    // Sparse: past the ceiling without writing 10 GiB
    let huge = try FileHandle(forWritingTo: processed.appendingPathComponent("huge.m4b"))
    try huge.truncate(atOffset: UInt64(FileUploadOperation.maxFileSize) + 1)
    try huge.close()

    XCTAssertEqual(
      SyncService.missingFileUpload(for: try item("ok.m4b")),
      MissingFileUpload(uuid: "u-ok.m4b", relativePath: "ok.m4b", fileURL: processed.appendingPathComponent("ok.m4b"))
    )
    XCTAssertNil(SyncService.missingFileUpload(for: try item("stream.m4b", mediaServer: true)))
    XCTAssertNil(SyncService.missingFileUpload(for: try item("missing.m4b")))
    XCTAssertNil(SyncService.missingFileUpload(for: try item("huge.m4b")))
    XCTAssertNil(SyncService.missingFileUpload(for: try item("ok.m4b", type: .folder)))
  }
}

// MARK: - When it runs

extension MissingItemsPassTests {
  private func markFirstSyncDone(lastRun: Date? = nil) {
    defaults.set(true, forKey: Constants.UserDefaults.hasScheduledLibraryContents)
    if let lastRun {
      defaults.set(lastRun.timeIntervalSince1970, forKey: Constants.UserDefaults.missingItemsPassLastRun)
    }
  }

  func testSchedule_runsOnceAWeek() async throws {
    markFirstSyncDone(lastRun: Date().addingTimeInterval(-24 * 60 * 60))
    await sync.scheduleMissingItemsIfNeeded()
    XCTAssertTrue(client.statusRequests.isEmpty, "a day after the last run")

    markFirstSyncDone(lastRun: Date().addingTimeInterval(-8 * 24 * 60 * 60))
    await sync.scheduleMissingItemsIfNeeded()
    XCTAssertEqual(client.statusRequests.count, 1)
    XCTAssertGreaterThan(
      defaults.double(forKey: Constants.UserDefaults.missingItemsPassLastRun),
      Date().addingTimeInterval(-60).timeIntervalSince1970
    )
  }

  /// Before the first sync, that sync is the pass; with changes queued, the server hasn't
  /// seen them yet (a queued import would come back unknown and be registered twice)
  func testSchedule_waitsForTheFirstSyncAndAnEmptySyncLane() async throws {
    await sync.scheduleMissingItemsIfNeeded()
    XCTAssertTrue(client.statusRequests.isEmpty, "before the first sync")

    markFirstSyncDone()
    let pending = book("Pending")
    await sync.jobManager.scheduleSetBookmarkJob(with: pending.relativePath, time: 10, note: nil, for: pending.uuid)
    await sync.scheduleMissingItemsIfNeeded()
    XCTAssertTrue(client.statusRequests.isEmpty, "with the sync lane busy")
  }

  /// The watch has downloaded files of its own: it never runs the pass
  func testSchedule_neverRunsWhereThePassIsOff() async throws {
    let watchSync = makeSyncService(runsMissingItemsPass: false)
    markFirstSyncDone()

    await watchSync.scheduleMissingItemsIfNeeded()

    XCTAssertTrue(client.statusRequests.isEmpty)
  }

  /// LITE → PRO: the books registered without their file can now upload, at once, and the
  /// continued task starts for them
  func testBecomingPro_runsThePassAtOnce_andStartsTheContinuedTask() async throws {
    markFirstSyncDone(lastRun: Date())
    defaults.set(false, forKey: Constants.UserDefaults.lastKnownProAccess)
    let lite = book("Registered on LITE")
    client.answer(unsynced: [lite.uuid])
    account.accessLevelValue = .pro
    let announced = expectation(forNotification: .bookUploadsQueued, object: nil)

    sync.noteProAccess()
    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.lastKnownProAccess))

    await fulfillment(of: [announced], timeout: 3)
    try await waitUntil { !defaults.bool(forKey: Constants.UserDefaults.missingItemsPassPending) }
    XCTAssertEqual(client.statusRequests.count, 1)
    let uploads = await uploadLane()
    XCTAssertEqual(uploads.map(\.uuid), [lite.uuid])
  }

  /// The first reading (an app update, a fresh install, a sign-in) is no tier change: an
  /// update mustn't start the continued task for every PRO user
  func testFirstTierReading_isNoTierChange() {
    account.accessLevelValue = .pro

    sync.noteProAccess()

    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.lastKnownProAccess))
    XCTAssertFalse(defaults.bool(forKey: Constants.UserDefaults.missingItemsPassPending))
  }

  /// A pending tier change stays pending until the queue has its PRO policy (the account
  /// update reaches it on its own hop): only then could its files be queued
  func testPendingPass_staysPendingUntilFilesCanBeQueued() async throws {
    markFirstSyncDone(lastRun: Date())
    defaults.set(true, forKey: Constants.UserDefaults.missingItemsPassPending)
    queue.accessPolicy = [.uploadFile: false, .externalUpdate: true]

    await sync.scheduleMissingItemsIfNeeded()

    XCTAssertEqual(client.statusRequests.count, 1)
    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.missingItemsPassPending))
  }

  /// Leaving PRO before the pass ran drops it: LITE has no files to send
  func testLeavingPro_dropsAPendingPass() {
    defaults.set(true, forKey: Constants.UserDefaults.missingItemsPassPending)
    defaults.set(true, forKey: Constants.UserDefaults.lastKnownProAccess)
    account.accessLevelValue = .lite

    sync.noteProAccess()

    XCTAssertFalse(defaults.bool(forKey: Constants.UserDefaults.missingItemsPassPending))
    XCTAssertFalse(defaults.bool(forKey: Constants.UserDefaults.lastKnownProAccess))
  }

  /// An account update gives the queue the new tier's policy before the lanes turn on. The
  /// refresh runs as the update is delivered, the lanes only in a later main-actor step, so a
  /// worker can't take a held upload under the old policy and drop it (a PRO user whose launch
  /// read was stale until RevenueCat answered)
  func testAccountUpdate_refreshesTheUploadPolicyBeforeTheLanesTurnOn() async throws {
    sync = launch(isActive: false, runsMissingItemsPass: true)
    let account = account!
    queue.getAccessLevel = { account.getAccessLevel() }
    queue.accessPolicy = [.uploadFile: false, .externalUpdate: true]
    account.account = accountRow(id: "user-1")
    account.hasSyncEnabledValue = true
    account.accessLevelValue = .pro

    NotificationCenter.default.post(name: .accountUpdate, object: nil)

    XCTAssertEqual(queue.accessPolicy[.uploadFile], true)
    XCTAssertFalse(queue.serverLanesEnabled, "the lanes turn on in a later main-actor step")
    try await waitUntil { queue.serverLanesEnabled }
  }

  /// An account row with this id: blank is how a signed-out account stays behind
  private func accountRow(id: String) -> Account {
    let row = Account(context: dataManager.getContext())
    row.id = id
    return row
  }

  private func launch(isActive: Bool, runsMissingItemsPass: Bool) -> SyncService {
    let service = SyncService()
    service.setup(
      isActive: isActive,
      libraryService: libraryService,
      accountService: account,
      syncQueueService: queue,
      client: client,
      runsMissingItemsPass: runsMissingItemsPass,
      userDefaults: defaults
    )
    queue.setServerLanesEnabled(false)
    return service
  }

  /// A lapse makes the return a first sync: what's imported meanwhile never reached the
  /// server, and a plain listing would delete it. Not on the watch
  func testLapse_makesTheReturnAFirstSync_onThePhoneOnly() async throws {
    markFirstSyncDone()
    let watch = launch(isActive: true, runsMissingItemsPass: false)
    watch.updateSyncEnabled(false)
    try await waitUntil { !watch.isActive }
    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents))

    sync.updateSyncEnabled(false)

    try await waitUntil { !defaults.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents) }
  }

  /// A lapse that happened while the app was closed shows up at launch: signed in, not syncing
  func testLaunchingLapsed_makesTheReturnAFirstSync() {
    markFirstSyncDone()
    account.account = accountRow(id: "user-1")

    _ = launch(isActive: false, runsMissingItemsPass: true)

    XCTAssertFalse(defaults.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents))
  }

  /// Signed out (the row stays, with a blank id), or on the watch, the flag is left alone
  func testLaunchingSignedOutOrOnTheWatch_leavesTheFirstSyncFlag() {
    markFirstSyncDone()
    account.account = accountRow(id: "")
    _ = launch(isActive: false, runsMissingItemsPass: true)

    account.account = accountRow(id: "user-1")
    _ = launch(isActive: false, runsMissingItemsPass: false)

    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents))
  }

  /// Sync went off and came back while the first sync waited on the server: that session's
  /// teardown wiped what it queued, so it mustn't mark the first sync done
  func testFirstSync_acrossASessionChange_isNotMarkedDone() async throws {
    let fresh = book("Fresh")
    client.answer(unknown: [fresh.uuid])
    let sync = sync!
    client.onStatus {
      sync.updateSyncEnabled(false)
      while await MainActor.run(body: { sync.isActive }) { try? await Task.sleep(for: .milliseconds(10)) }
      sync.updateSyncEnabled(true)
      while await MainActor.run(body: { !sync.isActive }) { try? await Task.sleep(for: .milliseconds(10)) }
    }

    try await sync.syncLibraryContents()

    XCTAssertFalse(defaults.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents))
    let lane = await syncLane()
    XCTAssertTrue(lane.isEmpty, "the old session registers nothing")
  }

  /// Work queued before sync went off is held, never cleared (a paying subscriber can read
  /// lapsed at launch): the first sync waits for it instead of wiping it
  func testFirstSync_waitsForHeldTasks_andKeepsThem() async throws {
    let held = book("Held")
    await sync.jobManager.scheduleSetBookmarkJob(with: held.relativePath, time: 10, note: nil, for: held.uuid)

    try await sync.syncLibraryContents()

    let lane = await syncLane()
    XCTAssertEqual(lane.map(\.jobType), [.setBookmark])
    XCTAssertTrue(client.statusRequests.isEmpty)
    XCTAssertFalse(defaults.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents))
  }

  /// The first sync registers by uuid and never deletes what the server doesn't list yet
  func testFirstSync_registersByUuid_andKeepsWhatTheServerLacks() async throws {
    let lapseImport = book("Imported while lapsed")
    client.answer(unknown: [lapseImport.uuid])
    client.setRootContent([SyncResponseFixtures.itemJSON(relativePath: "Remote.m4b")])
    defaults.set(true, forKey: Constants.UserDefaults.missingItemsPassPending)

    try await sync.syncLibraryContents()

    let exists = await libraryService.itemExists(for: lapseImport.relativePath)
    XCTAssertTrue(exists, "the first sync's listing must not delete it")
    let lane = await syncLane()
    XCTAssertEqual(lane.map(\.jobType), [.upload])
    XCTAssertEqual(lane.last?.uuid, lapseImport.uuid)
    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents))
    XCTAssertFalse(defaults.bool(forKey: Constants.UserDefaults.missingItemsPassPending))
    XCTAssertNotEqual(defaults.double(forKey: Constants.UserDefaults.missingItemsPassLastRun), 0)
  }
}
