//
//  LibraryOrganizerTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// The moves and folder changes the list's multi-select and the import's placement prompt share.
@MainActor
final class LibraryOrganizerTests: XCTestCase {
  private var libraryService: LibraryService!
  private var syncService: SyncServiceProtocolMock!
  private var playerManager: PlayerManagerProtocolMock!
  private var sut: LibraryOrganizer!

  override func setUp() {
    super.setUp()
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    libraryService = LibraryService()
    libraryService.setup(
      dataManager: DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null")),
      audioMetadataService: AudioMetadataService()
    )
    _ = libraryService.getLibrary()
    syncService = SyncServiceProtocolMock()
    playerManager = PlayerManagerProtocolMock()
    sut = LibraryOrganizer(libraryService: libraryService, syncService: syncService, playerManager: playerManager)
  }

  override func tearDown() {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    super.tearDown()
  }

  private func book(_ title: String) -> LibraryItemRef {
    let book = StubFactory.book(dataManager: libraryService.dataManager, title: title, duration: 10)
    libraryService.getLibraryReference().addToItems(book)
    libraryService.dataManager.saveContext()
    return LibraryItemRef(relativePath: book.relativePath, uuid: book.uuid)
  }

  private func playing(_ relativePath: String) -> PlayableItem {
    PlayableItem(
      title: "playing",
      author: "author",
      chapters: [PlayableChapter(title: "c", author: "a", start: 0, duration: 10, relativePath: relativePath, remoteURL: nil, index: 1)],
      currentTime: 0,
      duration: 10,
      relativePath: relativePath,
      uuid: "playing",
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
  }

  func testMovingIntoAFolderAndBackToTheRoot() throws {
    let item = book("Dune")
    let folder = try libraryService.createFolder(with: "Shelf", inside: nil)
    let folderRef = LibraryItemRef(relativePath: folder.relativePath, uuid: folder.uuid)

    try sut.move([item], into: folderRef)

    XCTAssertNotNil(libraryService.getSimpleItem(with: "Shelf/\(item.relativePath)"))
    XCTAssertEqual(syncService.scheduleMoveItemsToReceivedArguments?.parentFolder, folderRef)

    try sut.move([LibraryItemRef(relativePath: "Shelf/\(item.relativePath)", uuid: item.uuid)], into: nil)

    XCTAssertNotNil(libraryService.getSimpleItem(with: item.relativePath))
    XCTAssertNil(syncService.scheduleMoveItemsToReceivedArguments?.parentFolder)
  }

  func testANewVolumeHoldsTheItemsAndRegistersBeforeTheMove() async throws {
    let first = book("Part 1")
    let second = book("Part 2")

    let volume = try await sut.createFolder(titled: "  Saga  ", inside: nil, holding: [first, second], type: .bound)

    XCTAssertEqual(volume?.relativePath, "Saga")
    XCTAssertEqual(libraryService.getSimpleItem(with: "Saga")?.type, .bound)
    XCTAssertEqual(libraryService.fetchContents(at: "Saga", limit: nil, offset: nil)?.count, 2)
    XCTAssertEqual(syncService.scheduleUploadItemsReceivedItems?.map(\.relativePath), ["Saga"])
    XCTAssertEqual(syncService.scheduleMoveItemsToReceivedArguments?.parentFolder?.relativePath, "Saga")
    XCTAssertFalse(playerManager.stopCalled)
  }

  /// A moved book's path changes under the player.
  func testCreatingAFolderAroundThePlayingBookStopsIt() async throws {
    let item = book("Playing")
    playerManager.currentItem = playing(item.relativePath)

    try await sut.createFolder(titled: "Box", inside: nil, holding: [item], type: .folder)

    XCTAssertTrue(playerManager.stopCalled)
  }

  func testABlankTitleCreatesNothing() async throws {
    let created = try await sut.createFolder(titled: "   ", inside: nil, holding: [book("Dune")], type: .folder)

    XCTAssertNil(created)
    XCTAssertFalse(syncService.scheduleUploadItemsCalled)
    XCTAssertFalse(syncService.scheduleMoveItemsToCalled)
  }

  func testConvertingAFolderToAVolumeStopsPlaybackInsideIt() throws {
    let folder = try libraryService.createFolder(with: "Series", inside: nil)
    try libraryService.moveItems([book("Book")], inside: "Series")
    playerManager.currentItem = playing("Series/Book.txt")

    try sut.convert([folder], to: .bound)

    XCTAssertEqual(libraryService.getSimpleItem(with: "Series")?.type, .bound)
    XCTAssertTrue(playerManager.stopCalled)
  }
}
