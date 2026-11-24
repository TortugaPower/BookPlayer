//
//  PlayTimeCheckTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftData
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// The play-time check's decision (`SyncService.adoptNewerPlay`): the server's copy of the book about to play
/// is stored only when another device played it after this one, in whole seconds, and then moves position,
/// progress, finished and play date whichever way. Main actor: the tests read the view context.
@MainActor
final class PlayTimeCheckTests: XCTestCase {
  /// Answers the one-item GET from what the test set, and records each request
  private final class ItemClient: NetworkClientMock, @unchecked Sendable {
    private let lock = NSLock()
    private var _answer: [String: Any]?
    private var _fails = false
    private var _requests = [(path: String, parameters: [String: Any])]()

    var requests: [(path: String, parameters: [String: Any])] { lock.withLock { _requests } }

    init() {
      super.init(mockedResponse: Empty())
    }

    func answer(_ item: [String: Any]) {
      lock.withLock { _answer = item }
    }

    func fail() {
      lock.withLock { _fails = true }
    }

    override func request<T: Decodable>(
      path: String,
      method: HTTPMethod,
      parameters: [String: Any]?
    ) async throws -> T {
      let content: [[String: Any]] = try lock.withLock {
        _requests.append((path, parameters ?? [:]))
        if _fails { throw URLError(.timedOut) }
        return _answer.map { [$0] } ?? []
      }
      return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: ["content": content]))
    }
  }

  private var tasksDataManager: TasksDataManager!
  private var dataManager: DataManager!
  private var libraryService: LibraryService!
  private var queue: SyncQueueService!
  private var client: ItemClient!
  private var sync: SyncService!
  private var defaults: UserDefaults!
  private var defaultsSuite = ""

  /// When this device last played the book: 1,000,000.7 s, so its whole second is 1,000,000
  private let localPlay = Date(timeIntervalSince1970: 1_000_000.7)

  override func setUpWithError() throws {
    defaultsSuite = "PlayTimeCheckTests-\(UUID().uuidString)"
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

    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: AudioMetadataService())
    _ = libraryService.getLibrary()

    client = ItemClient()
    queue = SyncQueueService(maxConcurrentTasks: 1)
    queue.taskContainer = SyncQueueRepository(tasksDataManager: tasksDataManager)
    queue.tasksDataManager = tasksDataManager
    sync = SyncService()
    sync.setup(
      isActive: true,
      libraryService: libraryService,
      accountService: AccountServiceMock(account: nil),
      syncQueueService: queue,
      client: client,
      userDefaults: defaults
    )
    // Nothing here queues server work, and none of it should run
    queue.setServerLanesEnabled(false)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: defaultsSuite)
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    sync = nil
    queue = nil
    tasksDataManager = nil
    super.tearDown()
  }

  // MARK: - Helpers

  /// A book this device last played at `localPlay`, 30 s in
  private func playedBook() -> Book {
    let book = StubFactory.book(dataManager: dataManager, title: "Dune", duration: 100)
    book.currentTime = 30
    book.percentCompleted = 30
    book.lastPlayDate = localPlay
    dataManager.saveContext()
    return book
  }

  /// The server's copy of `book`, played at `playedAt` (seconds, as the server stores them)
  private func serverCopy(
    of book: Book,
    uuid: String? = nil,
    currentTime: Double,
    isFinished: Bool = false,
    playedAt: Double
  ) -> [String: Any] {
    [
      "relativePath": book.relativePath!,
      "originalFileName": book.originalFileName!,
      "title": book.title!,
      "details": book.details!,
      "currentTime": currentTime,
      "duration": book.duration,
      "percentCompleted": currentTime,
      "isFinished": isFinished,
      "orderRank": 0,
      "lastPlayDateTimestamp": playedAt,
      "type": SimpleItemType.book.rawValue,
      "uuid": uuid ?? book.uuid,
    ]
  }

  private func check(_ book: Book, playedAt: Date?) async -> Bool {
    await sync.adoptNewerPlay(of: book.relativePath, uuid: book.uuid, playedAt: playedAt)
  }

  /// The row as it's saved now
  private func stored(_ book: Book) throws -> SimpleLibraryItem {
    try XCTUnwrap(libraryService.getSimpleItem(with: book.relativePath))
  }

  // MARK: - Newer, older, same second

  /// The item itself, by path and uuid, without its contents (no trailing slash), the last-played book or
  /// a presigned URL
  func testAsksForTheBookItself() async {
    let book = playedBook()
    client.answer(serverCopy(of: book, currentTime: 30, playedAt: 1_000_000))

    _ = await check(book, playedAt: localPlay)

    XCTAssertEqual(client.requests.count, 1)
    let request = client.requests[0]
    XCTAssertEqual(request.path, "/v1/library")
    XCTAssertEqual(request.parameters["relativePath"] as? String, book.relativePath)
    XCTAssertEqual(request.parameters["uuid"] as? String, book.uuid)
    XCTAssertEqual(request.parameters["noLastItemPlayed"] as? Bool, true)
    XCTAssertNil(request.parameters["sign"])
  }

  /// Another device listened on: its position, progress and play date are stored
  func testANewerPlayIsStored() async throws {
    let book = playedBook()
    client.answer(serverCopy(of: book, currentTime: 70, playedAt: 1_000_500))

    let adopted = await check(book, playedAt: localPlay)

    XCTAssertTrue(adopted)
    let row = try stored(book)
    XCTAssertEqual(row.currentTime, 70)
    XCTAssertEqual(row.percentCompleted, 70)
    XCTAssertEqual(row.lastPlayDate, Date(timeIntervalSince1970: 1_000_500))
  }

  /// The other device rewound: newer wins whichever way the position moved
  func testANewerPlayFurtherBackIsStored() async throws {
    let book = playedBook()
    client.answer(serverCopy(of: book, currentTime: 5, playedAt: 1_000_001))

    let adopted = await check(book, playedAt: localPlay)

    XCTAssertTrue(adopted)
    XCTAssertEqual(try stored(book).currentTime, 5)
  }

  /// Finished on another device
  func testANewerFinishedPlayIsStored() async throws {
    let book = playedBook()
    client.answer(serverCopy(of: book, currentTime: 100, isFinished: true, playedAt: 1_000_500))

    let adopted = await check(book, playedAt: localPlay)

    XCTAssertTrue(adopted)
    XCTAssertTrue(try stored(book).isFinished)
  }

  /// This device played it last: nothing changes
  func testAnOlderPlayIsIgnored() async throws {
    let book = playedBook()
    client.answer(serverCopy(of: book, currentTime: 70, playedAt: 999_000))

    let adopted = await check(book, playedAt: localPlay)

    XCTAssertFalse(adopted)
    XCTAssertEqual(try stored(book).currentTime, 30)
  }

  /// This device's own play read back: the server keeps whole seconds (1,000,000.7 → 1,000,000)
  func testAPlayInTheSameSecondIsIgnored() async throws {
    let book = playedBook()
    client.answer(serverCopy(of: book, currentTime: 70, playedAt: 1_000_000))

    let adopted = await check(book, playedAt: localPlay)

    XCTAssertFalse(adopted)
    XCTAssertEqual(try stored(book).currentTime, 30)
  }

  /// Under a second later, in the next whole second: newer
  func testAPlayInTheNextSecondIsStored() async throws {
    let book = playedBook()
    client.answer(serverCopy(of: book, currentTime: 70, playedAt: 1_000_001))

    let adopted = await check(book, playedAt: localPlay)

    XCTAssertTrue(adopted)
    XCTAssertEqual(try stored(book).currentTime, 70)
  }

  /// Never played on this device
  func testAnyServerPlayIsNewerThanNone() async throws {
    let book = playedBook()
    client.answer(serverCopy(of: book, currentTime: 70, playedAt: 1))

    let adopted = await check(book, playedAt: nil)

    XCTAssertTrue(adopted)
    XCTAssertEqual(try stored(book).currentTime, 70)
  }

  // MARK: - No answer

  /// Offline, timed out, a server error: the play goes on from here
  func testAFailedRequestChangesNothing() async throws {
    let book = playedBook()
    client.fail()

    let adopted = await check(book, playedAt: localPlay)

    XCTAssertFalse(adopted)
    XCTAssertEqual(try stored(book).currentTime, 30)
  }

  /// The server doesn't have it
  func testNoItemChangesNothing() async throws {
    let book = playedBook()

    let adopted = await check(book, playedAt: localPlay)

    XCTAssertFalse(adopted)
    XCTAssertEqual(try stored(book).currentTime, 30)
  }

  /// Another item answered at that path: never stored over this book
  func testAnotherItemsPlayIsIgnored() async throws {
    let book = playedBook()
    client.answer(serverCopy(of: book, uuid: UUID().uuidString, currentTime: 70, playedAt: 1_000_500))

    let adopted = await check(book, playedAt: localPlay)

    XCTAssertFalse(adopted)
    XCTAssertEqual(try stored(book).currentTime, 30)
  }

  func testWithoutSyncNothingIsAsked() async {
    let book = playedBook()
    sync.updateSyncEnabled(false)
    await waitUntil { !self.sync.isActive }

    let adopted = await check(book, playedAt: localPlay)

    XCTAssertFalse(adopted)
    XCTAssertTrue(client.requests.isEmpty)
  }

  private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
      guard Date() < deadline else {
        XCTFail("timed out")
        return
      }
      try? await Task.sleep(for: .milliseconds(10))
    }
  }
}
