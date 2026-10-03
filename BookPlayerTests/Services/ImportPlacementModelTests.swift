//
//  ImportPlacementModelTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// The placement prompt's options act on the imported items where they are when an option is
/// picked. An import made inside a folder lands at the root and is moved into that folder before
/// the prompt shows, so the paths it was built with no longer exist: "Library", "New folder" and
/// "Create a volume" found nothing to act on.
@MainActor
final class ImportPlacementModelTests: XCTestCase {
  private var libraryService: LibraryService!
  private var syncService: SyncServiceProtocolMock!
  private var sut: ImportPlacementModel!
  private var shelf: SimpleLibraryItem!

  override func setUpWithError() throws {
    try super.setUpWithError()
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    libraryService = LibraryService()
    libraryService.setup(
      dataManager: DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null")),
      audioMetadataService: AudioMetadataService()
    )
    _ = libraryService.getLibrary()
    syncService = SyncServiceProtocolMock()
    sut = ImportPlacementModel(
      libraryService: libraryService,
      syncService: syncService,
      playerManager: PlayerManagerProtocolMock()
    )
    shelf = try libraryService.createFolder(with: "Shelf", inside: nil)
  }

  override func tearDown() {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    super.tearDown()
  }

  /// A book imported at the root, then moved into Shelf as an import made inside it is
  private func importIntoShelf(_ titles: [String]) throws -> [String] {
    let refs = titles.map { title -> LibraryItemRef in
      let book = StubFactory.book(dataManager: libraryService.dataManager, title: title, duration: 10)
      libraryService.getLibraryReference().addToItems(book)
      return LibraryItemRef(relativePath: book.relativePath, uuid: book.uuid)
    }
    libraryService.dataManager.saveContext()
    try libraryService.moveItems(refs, inside: shelf.relativePath)

    return refs.map(\.uuid)
  }

  private func placement(_ uuids: [String], singleFolderUuid: String? = nil, folders: [SimpleLibraryItem] = []) -> ImportPlacement {
    ImportPlacement(
      itemUuids: uuids,
      hasOnlyBooks: singleFolderUuid == nil,
      singleFolderUuid: singleFolderUuid,
      availableFolders: folders,
      suggestedFolderName: nil,
      node: .folder(title: shelf.title, relativePath: shelf.relativePath, uuid: shelf.uuid)
    )
  }

  func testTheItemsAreFoundWhereTheyAreNow() throws {
    let uuids = try importIntoShelf(["Dune", "Emma"])

    XCTAssertEqual(sut.items(of: placement(uuids)).map(\.relativePath), ["Shelf/Dune.txt", "Shelf/Emma.txt"])
    XCTAssertEqual(
      sut.items(of: placement(uuids + ["gone"])).map(\.uuid),
      uuids,
      "an item deleted meanwhile is left out"
    )
  }

  func testLibraryMovesTheImportOutOfTheFolder() throws {
    let uuids = try importIntoShelf(["Dune"])

    try sut.moveToLibrary(placement(uuids))

    XCTAssertNotNil(libraryService.getSimpleItem(with: "Dune.txt"))
    XCTAssertNil(libraryService.getSimpleItem(with: "Shelf/Dune.txt"))
  }

  func testAnExistingFolderReceivesTheImport() throws {
    let uuids = try importIntoShelf(["Dune"])
    let box = try libraryService.createFolder(with: "Box", inside: shelf.relativePath)

    try sut.move(placement(uuids, folders: [box]), into: box)

    XCTAssertNotNil(libraryService.getSimpleItem(with: "Shelf/Box/Dune.txt"))
  }

  func testANewVolumeIsCreatedWhereTheImportLanded() async throws {
    let uuids = try importIntoShelf(["Part 1", "Part 2"])

    try await sut.createFolder(titled: "Saga", for: placement(uuids), type: .bound)

    XCTAssertEqual(libraryService.getSimpleItem(with: "Shelf/Saga")?.type, .bound)
    XCTAssertEqual(libraryService.fetchContents(at: "Shelf/Saga", limit: nil, offset: nil)?.count, 2)
  }

  /// An imported folder, moved into Shelf: "Create a volume" turns that one into a volume.
  func testAnImportedFolderBecomesAVolumeWhereItIsNow() throws {
    let folder = try libraryService.createFolder(with: "Series", inside: nil)
    let book = StubFactory.book(dataManager: libraryService.dataManager, title: "Part", duration: 10)
    libraryService.getLibraryReference().addToItems(book)
    libraryService.dataManager.saveContext()
    try libraryService.moveItems([LibraryItemRef(relativePath: book.relativePath, uuid: book.uuid)], inside: "Series")
    try libraryService.moveItems([LibraryItemRef(relativePath: folder.relativePath, uuid: folder.uuid)], inside: shelf.relativePath)

    try sut.makeVolume(of: placement([folder.uuid], singleFolderUuid: folder.uuid))

    XCTAssertEqual(libraryService.getSimpleItem(with: "Shelf/Series")?.type, .bound)
  }
}
