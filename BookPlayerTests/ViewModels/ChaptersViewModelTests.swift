//
//  ChaptersViewModelTests.swift
//  BookPlayerTests
//
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

@MainActor
final class ChaptersViewModelTests: XCTestCase {
  private var playerManagerMock: PlayerManagerProtocolMock!
  private var libraryServiceMock: LibraryServiceProtocolMock!

  override func setUp() {
    super.setUp()
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    playerManagerMock = PlayerManagerProtocolMock()
    libraryServiceMock = LibraryServiceProtocolMock()
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
    playerManagerMock.currentItem = makeItem(relativePath: "book.m4b", isBoundBook: false)
    XCTAssertTrue(makeSUT().canReloadChapters)
  }

  func testCanReloadChapters_boundBook_isFalse() {
    playerManagerMock.currentItem = makeItem(relativePath: "folder", isBoundBook: true)
    XCTAssertFalse(makeSUT().canReloadChapters)
  }

  func testReloadChapters_whenMoreFound_reloadsItemAndRefreshesList() async {
    createLocalFile(named: "reparse.m4b")
    playerManagerMock.currentItem = makeItem(relativePath: "reparse.m4b", isBoundBook: false, chapterCount: 1)
    libraryServiceMock.reloadChaptersRelativePathReturnValue = 5
    // Simulate PlayerManager rebuilding currentItem from storage with the new chapter count.
    let reloadedItem = makeItem(relativePath: "reparse.m4b", isBoundBook: false, chapterCount: 5)
    playerManagerMock.reloadCurrentItemClosure = { [weak self] in
      self?.playerManagerMock.currentItem = reloadedItem
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
    playerManagerMock.currentItem = makeItem(relativePath: "missing.m4b", isBoundBook: false)
    let sut = makeSUT()

    await sut.reloadChapters()

    XCTAssertFalse(libraryServiceMock.reloadChaptersRelativePathCalled)
    XCTAssertFalse(playerManagerMock.reloadCurrentItemCalled)
    XCTAssertNotNil(sut.currentAlert)
    XCTAssertFalse(sut.isReloadingChapters)
  }

  func testReloadChapters_whenNoAdditionalFound_alertsAndDoesNotReloadItem() async {
    createLocalFile(named: "none.m4b")
    playerManagerMock.currentItem = makeItem(relativePath: "none.m4b", isBoundBook: false)
    libraryServiceMock.reloadChaptersRelativePathReturnValue = nil
    let sut = makeSUT()

    await sut.reloadChapters()

    XCTAssertTrue(libraryServiceMock.reloadChaptersRelativePathCalled)
    XCTAssertFalse(playerManagerMock.reloadCurrentItemCalled)
    XCTAssertNotNil(sut.currentAlert)
    XCTAssertFalse(sut.isReloadingChapters)
  }

  func testReloadChapters_boundBook_isNoOp() async {
    playerManagerMock.currentItem = makeItem(relativePath: "folder", isBoundBook: true)
    let sut = makeSUT()

    await sut.reloadChapters()

    XCTAssertFalse(libraryServiceMock.reloadChaptersRelativePathCalled)
    XCTAssertNil(sut.currentAlert)
  }
}
