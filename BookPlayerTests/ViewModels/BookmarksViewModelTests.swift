//
//  BookmarksViewModelTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import CoreData
import XCTest

@MainActor
final class BookmarksViewModelTests: XCTestCase {
  private var playerManagerMock: PlayerManagerProtocolMock!
  private var libraryServiceMock: LibraryServiceProtocolMock!
  private var syncServiceMock: SyncServiceProtocolMock!
  /// A real store, for object IDs of real entities
  private var dataManager: DataManager!
  private var context: NSManagedObjectContext { dataManager.getContext() }

  override func setUp() {
    super.setUp()
    playerManagerMock = PlayerManagerProtocolMock()
    libraryServiceMock = LibraryServiceProtocolMock()
    syncServiceMock = SyncServiceProtocolMock()
    dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))

    let item = PlayableItem(
      title: "title",
      author: "author",
      chapters: [
        PlayableChapter(
          title: "chapter 1",
          author: "author",
          start: 0,
          duration: 100,
          relativePath: "book.m4b",
          remoteURL: nil,
          externalURL: nil,
          index: 0
        )
      ],
      currentTime: 0,
      duration: 100,
      relativePath: "book.m4b",
      uuid: "uuid",
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
    playerManagerMock.currentItemPublisherReturnValue = Just(item).eraseToAnyPublisher()
  }

  private func makeSUT() -> BookmarksViewModel {
    BookmarksViewModel(
      playerManager: playerManagerMock,
      libraryService: libraryServiceMock,
      syncService: syncServiceMock
    )
  }

  /// What a save posts, with the IDs of the objects it inserted
  private func postSave(inserting objects: [NSManagedObject]) {
    NotificationCenter.default.post(
      name: NSManagedObjectContext.didSaveObjectIDsNotification,
      object: context,
      userInfo: [
        NSManagedObjectContext.NotificationKey.insertedObjectIDs.rawValue: Set(objects.map(\.objectID))
      ]
    )
  }

  private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline, !condition() {
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  func testSaveTouchingABookmark_reloadsTheList() async throws {
    let sut = makeSUT()
    let bookmark = SimpleBookmark(time: 10, note: nil, type: .user, relativePath: "book.m4b", uuid: "uuid")
    libraryServiceMock.getBookmarksOfRelativePathClosure = { type, _ in
      type == .user ? [bookmark] : []
    }

    postSave(inserting: [Bookmark(with: 10, type: .user, context: context)])

    try await waitUntil { sut.userBookmarks.count == 1 }
    XCTAssertEqual(sut.userBookmarks.map(\.time), [10])
  }

  func testSaveTouchingOtherEntities_doesNotReload() async throws {
    let sut = makeSUT()
    let callsAfterLoading = libraryServiceMock.getBookmarksOfRelativePathCallsCount

    postSave(inserting: [NSEntityDescription.insertNewObject(forEntityName: "Chapter", into: context)])
    try await Task.sleep(for: .milliseconds(200))

    withExtendedLifetime(sut) {
      XCTAssertEqual(libraryServiceMock.getBookmarksOfRelativePathCallsCount, callsAfterLoading)
    }
  }
}
