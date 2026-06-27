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

  private func makeItem(relativePath: String, isBoundBook: Bool) -> PlayableItem {
    PlayableItem(
      title: "title",
      author: "author",
      chapters: [
        PlayableChapter(
          title: "chapter",
          author: "author",
          start: 0,
          duration: 100,
          relativePath: relativePath,
          remoteURL: nil,
          index: 0
        )
      ],
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

  func testReloadChapters_whenMoreFound_reloadsItemAndAlerts() async {
    createLocalFile(named: "reparse.m4b")
    playerManagerMock.currentItem = makeItem(relativePath: "reparse.m4b", isBoundBook: false)
    libraryServiceMock.reloadChaptersRelativePathReturnValue = 5
    let sut = makeSUT()

    await sut.reloadChapters()

    XCTAssertTrue(libraryServiceMock.reloadChaptersRelativePathCalled)
    XCTAssertTrue(playerManagerMock.reloadCurrentItemCalled)
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
  }

  func testReloadChapters_boundBook_isNoOp() async {
    playerManagerMock.currentItem = makeItem(relativePath: "folder", isBoundBook: true)
    let sut = makeSUT()

    await sut.reloadChapters()

    XCTAssertFalse(libraryServiceMock.reloadChaptersRelativePathCalled)
    XCTAssertNil(sut.currentAlert)
  }
}
