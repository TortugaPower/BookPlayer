//
//  BookmarksViewModelTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

@MainActor
final class BookmarksViewModelTests: XCTestCase {
  private var playerManagerMock: PlayerManagerProtocolMock!
  private var libraryServiceMock: LibraryServiceProtocolMock!
  private var syncServiceMock: SyncServiceProtocolMock!
  /// What the library sends when it writes a book's bookmarks
  private var bookmarksUpdates: PassthroughSubject<String, Never>!

  override func setUp() {
    super.setUp()
    playerManagerMock = PlayerManagerProtocolMock()
    libraryServiceMock = LibraryServiceProtocolMock()
    syncServiceMock = SyncServiceProtocolMock()
    bookmarksUpdates = PassthroughSubject<String, Never>()
    libraryServiceMock.bookmarksUpdatePublisher = bookmarksUpdates.eraseToAnyPublisher()

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

  private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline, !condition() {
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  func testBookmarkWrittenForTheBook_reloadsTheList() async throws {
    let sut = makeSUT()
    let bookmark = SimpleBookmark(time: 10, note: nil, type: .user, relativePath: "book.m4b", uuid: "uuid")
    libraryServiceMock.getBookmarksOfRelativePathClosure = { type, _ in
      type == .user ? [bookmark] : []
    }

    bookmarksUpdates.send("book.m4b")

    try await waitUntil { sut.userBookmarks.count == 1 }
    XCTAssertEqual(sut.userBookmarks.map(\.time), [10])
  }

  func testBurstOfBookmarkWrites_reloadsOnce() async throws {
    let sut = makeSUT()
    let callsAfterLoading = libraryServiceMock.getBookmarksOfRelativePathCallsCount
    let bookmark = SimpleBookmark(time: 10, note: nil, type: .user, relativePath: "book.m4b", uuid: "uuid")
    libraryServiceMock.getBookmarksOfRelativePathClosure = { type, _ in
      type == .user ? [bookmark] : []
    }

    for _ in 0..<5 {
      bookmarksUpdates.send("book.m4b")
    }

    try await waitUntil { sut.userBookmarks.count == 1 }
    try await Task.sleep(for: .milliseconds(300))
    /// One reload reads the four bookmark types once each
    XCTAssertEqual(libraryServiceMock.getBookmarksOfRelativePathCallsCount, callsAfterLoading + 4)
  }

  func testBookmarkWrittenForAnotherBook_doesNotReload() async throws {
    let sut = makeSUT()
    let callsAfterLoading = libraryServiceMock.getBookmarksOfRelativePathCallsCount

    bookmarksUpdates.send("another book.m4b")
    try await Task.sleep(for: .milliseconds(200))

    withExtendedLifetime(sut) {
      XCTAssertEqual(libraryServiceMock.getBookmarksOfRelativePathCallsCount, callsAfterLoading)
    }
  }
}
