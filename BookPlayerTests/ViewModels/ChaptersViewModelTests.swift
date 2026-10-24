//
//  ChaptersViewModelTests.swift
//  BookPlayerTests
//
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

@MainActor
final class ChaptersViewModelTests: XCTestCase {
  private var playerManagerMock: PlayerManagerProtocolMock!
  private var libraryServiceMock: LibraryServiceProtocolMock!
  /// Stands in for `PlayerManager.$currentItem`, which the view model follows
  private var currentItemSubject: CurrentValueSubject<PlayableItem?, Never>!

  override func setUp() {
    super.setUp()
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    playerManagerMock = PlayerManagerProtocolMock()
    libraryServiceMock = LibraryServiceProtocolMock()
    currentItemSubject = CurrentValueSubject(nil)
    playerManagerMock.currentItemPublisherReturnValue = currentItemSubject.eraseToAnyPublisher()
  }

  /// Like `PlayerManager`: the property and its publisher change together
  private func setCurrentItem(_ item: PlayableItem?) {
    playerManagerMock.currentItem = item
    currentItemSubject.send(item)
  }

  private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline, !condition() {
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  private func makeItem(relativePath: String, isBoundBook: Bool, chapterCount: Int = 1) -> PlayableItem {
    let chapters = (0..<chapterCount).map { index in
      PlayableChapter(
        title: "chapter \(index + 1)",
        author: "author",
        start: Double(index) * 10,
        duration: 10,
        relativePath: relativePath,
        remoteURL: nil,
        externalURL: nil,
        index: Int16(index)
      )
    }
    return PlayableItem(
      title: "title",
      author: "author",
      chapters: chapters,
      currentTime: 0,
      duration: 100,
      relativePath: relativePath,
      uuid: "uuid",
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: isBoundBook
    )
  }

  private func makeSUT() -> ChaptersViewModel {
    ChaptersViewModel(playerManager: playerManagerMock, libraryService: libraryServiceMock)
  }

  private func createLocalFile(named name: String) {
    _ = DataTestUtils.generateTestFile(
      name: name,
      contents: Data("stub".utf8),
      destinationFolder: DataManager.getProcessedFolderURL()
    )
  }

  func testCanReloadChapters_singleFileBook_isTrue() {
    setCurrentItem(makeItem(relativePath: "book.m4b", isBoundBook: false))
    XCTAssertTrue(makeSUT().canReloadChapters)
  }

  func testCanReloadChapters_boundBook_isFalse() {
    setCurrentItem(makeItem(relativePath: "folder", isBoundBook: true))
    XCTAssertFalse(makeSUT().canReloadChapters)
  }

  func testReloadChapters_whenMoreFound_reloadsItemAndRefreshesList() async {
    createLocalFile(named: "reparse.m4b")
    setCurrentItem(makeItem(relativePath: "reparse.m4b", isBoundBook: false, chapterCount: 1))
    libraryServiceMock.reloadChaptersRelativePathReturnValue = 5
    // Simulate PlayerManager rebuilding currentItem from storage with the new chapter count.
    let reloadedItem = makeItem(relativePath: "reparse.m4b", isBoundBook: false, chapterCount: 5)
    playerManagerMock.reloadCurrentItemClosure = { [weak self] in
      self?.setCurrentItem(reloadedItem)
    }
    let sut = makeSUT()

    await sut.reloadChapters()

    XCTAssertTrue(libraryServiceMock.reloadChaptersRelativePathCalled)
    XCTAssertTrue(playerManagerMock.reloadCurrentItemCalled)
    XCTAssertEqual(sut.chapters.count, 5)
    XCTAssertNotNil(sut.currentAlert)
    XCTAssertFalse(sut.isReloadingChapters)
  }

  func testReloadChapters_whenFileNotDownloaded_alertsWithoutParsing() async {
    // No file created on disk for this relativePath.
    setCurrentItem(makeItem(relativePath: "missing.m4b", isBoundBook: false))
    let sut = makeSUT()

    await sut.reloadChapters()

    XCTAssertFalse(libraryServiceMock.reloadChaptersRelativePathCalled)
    XCTAssertFalse(playerManagerMock.reloadCurrentItemCalled)
    XCTAssertNotNil(sut.currentAlert)
    XCTAssertFalse(sut.isReloadingChapters)
  }

  func testReloadChapters_whenNoAdditionalFound_alertsAndDoesNotReloadItem() async {
    createLocalFile(named: "none.m4b")
    setCurrentItem(makeItem(relativePath: "none.m4b", isBoundBook: false))
    libraryServiceMock.reloadChaptersRelativePathReturnValue = nil
    let sut = makeSUT()

    await sut.reloadChapters()

    XCTAssertTrue(libraryServiceMock.reloadChaptersRelativePathCalled)
    XCTAssertFalse(playerManagerMock.reloadCurrentItemCalled)
    XCTAssertNotNil(sut.currentAlert)
    XCTAssertFalse(sut.isReloadingChapters)
  }

  func testReloadChapters_boundBook_isNoOp() async {
    setCurrentItem(makeItem(relativePath: "folder", isBoundBook: true))
    let sut = makeSUT()

    await sut.reloadChapters()

    XCTAssertFalse(libraryServiceMock.reloadChaptersRelativePathCalled)
    XCTAssertNil(sut.currentAlert)
  }

  func testCurrentChapter_followsPlayback() async throws {
    let item = makeItem(relativePath: "book.m4b", isBoundBook: false, chapterCount: 3)
    item.currentChapter = item.chapters[0]
    setCurrentItem(item)
    let sut = makeSUT()

    item.currentChapter = item.chapters[2]

    try await waitUntil { sut.currentChapter == item.chapters[2] }
    XCTAssertEqual(sut.currentChapter, item.chapters[2])
  }

  func testChapters_followTheCurrentItem() async throws {
    setCurrentItem(makeItem(relativePath: "first.m4b", isBoundBook: false, chapterCount: 2))
    let sut = makeSUT()
    let next = makeItem(relativePath: "second.m4b", isBoundBook: false, chapterCount: 4)
    next.currentChapter = next.chapters[1]

    setCurrentItem(next)

    try await waitUntil { sut.chapters == next.chapters && sut.currentChapter == next.chapters[1] }
    XCTAssertEqual(sut.chapters, next.chapters)
    XCTAssertEqual(sut.currentChapter, next.chapters[1])
  }
}
