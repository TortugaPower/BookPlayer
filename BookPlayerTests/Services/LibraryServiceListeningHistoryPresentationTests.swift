//
//  LibraryServiceListeningHistoryPresentationTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

final class LibraryServiceListeningHistoryPresentationTests: XCTestCase {
  var sut: LibraryService!

  override func setUp() {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let audioMetadataService = AudioMetadataService()
    sut = LibraryService()
    sut.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    _ = sut.getLibrary()
  }

  func testPresentation_bookInFolder_usesFolderTitle() throws {
    let folder = try sut.createFolder(with: "Albums", inside: nil)
    let book = StubFactory.book(dataManager: sut.dataManager, title: "raw-file-name", duration: 100)
    sut.getLibraryReference().addToItems(book)
    sut.dataManager.saveContext()

    try sut.moveItems(
      [LibraryItemRef(relativePath: book.relativePath, uuid: book.uuid)],
      inside: folder.relativePath
    )

    let presentation = sut.listeningHistoryPresentation(
      for: book.relativePath,
      fallbackTitle: "fallback"
    )

    XCTAssertEqual(presentation.title, "Albums")
    XCTAssertEqual(presentation.subtitle, "raw-file-name")
    XCTAssertEqual(presentation.artworkRelativePath, folder.relativePath)
    XCTAssertEqual(presentation.loadRelativePath, book.relativePath)
  }

  func testPresentation_nestedFolders_buildsBreadcrumb() throws {
    let outer = try sut.createFolder(with: "Outer", inside: nil)
    let inner = try sut.createFolder(with: "Inner", inside: outer.relativePath)
    let book = StubFactory.book(dataManager: sut.dataManager, title: "Chapter 01", duration: 50)
    sut.getLibraryReference().addToItems(book)
    sut.dataManager.saveContext()

    try sut.moveItems(
      [LibraryItemRef(relativePath: book.relativePath, uuid: book.uuid)],
      inside: inner.relativePath
    )

    let presentation = sut.listeningHistoryPresentation(
      for: book.relativePath,
      fallbackTitle: "fallback"
    )

    XCTAssertEqual(presentation.title, "Outer / Inner")
    XCTAssertEqual(presentation.subtitle, "Chapter 01")
    XCTAssertEqual(presentation.artworkRelativePath, inner.relativePath)
    XCTAssertEqual(presentation.loadRelativePath, book.relativePath)
  }

  func testPresentation_boundBook_usesBoundTitle() throws {
    let bound = try sut.createFolder(with: "Full Audiobook", inside: nil)
    let chapter = StubFactory.book(dataManager: sut.dataManager, title: "ch1", duration: 100)
    sut.getLibraryReference().addToItems(chapter)
    sut.dataManager.saveContext()
    try sut.moveItems(
      [LibraryItemRef(relativePath: chapter.relativePath, uuid: chapter.uuid)],
      inside: bound.relativePath
    )
    try sut.updateFolder(at: bound.relativePath, type: .bound)

    let presentation = sut.listeningHistoryPresentation(
      for: bound.relativePath,
      fallbackTitle: "fallback"
    )

    XCTAssertEqual(presentation.title, "Full Audiobook")
    XCTAssertNil(presentation.subtitle)
    XCTAssertEqual(presentation.artworkRelativePath, bound.relativePath)
    XCTAssertEqual(presentation.loadRelativePath, bound.relativePath)
  }

  func testPresentation_boundInsideFolder_showsOuterFolderAsSubtitle() throws {
    let outer = try sut.createFolder(with: "Series", inside: nil)
    let bound = try sut.createFolder(with: "Book One", inside: outer.relativePath)
    let chapter = StubFactory.book(dataManager: sut.dataManager, title: "ch1", duration: 100)
    sut.getLibraryReference().addToItems(chapter)
    sut.dataManager.saveContext()
    try sut.moveItems(
      [LibraryItemRef(relativePath: chapter.relativePath, uuid: chapter.uuid)],
      inside: bound.relativePath
    )
    try sut.updateFolder(at: bound.relativePath, type: .bound)

    let presentation = sut.listeningHistoryPresentation(
      for: bound.relativePath,
      fallbackTitle: "fallback"
    )

    XCTAssertEqual(presentation.title, "Book One")
    XCTAssertEqual(presentation.subtitle, "Series")
    XCTAssertEqual(presentation.loadRelativePath, bound.relativePath)
  }

  func testPresentation_rootBook_usesBookTitle() {
    let book = StubFactory.book(dataManager: sut.dataManager, title: "Standalone", duration: 100)
    sut.getLibraryReference().addToItems(book)
    sut.dataManager.saveContext()

    let presentation = sut.listeningHistoryPresentation(
      for: book.relativePath,
      fallbackTitle: "fallback"
    )

    XCTAssertEqual(presentation.title, "Standalone")
    XCTAssertNil(presentation.subtitle)
    XCTAssertEqual(presentation.artworkRelativePath, book.relativePath)
    XCTAssertEqual(presentation.loadRelativePath, book.relativePath)
  }

  func testPresentation_missingItem_usesFallbackTitle() {
    let presentation = sut.listeningHistoryPresentation(
      for: "missing/path.mp3",
      fallbackTitle: "Saved Snapshot"
    )

    XCTAssertEqual(presentation.title, "Saved Snapshot")
    XCTAssertNil(presentation.subtitle)
    XCTAssertEqual(presentation.artworkRelativePath, "missing/path.mp3")
    XCTAssertEqual(presentation.loadRelativePath, "missing/path.mp3")
  }

  func testStartListeningSession_storesResolvedFolderTitleSnapshot() throws {
    let folder = try sut.createFolder(with: "Podcasts", inside: nil)
    let book = StubFactory.book(dataManager: sut.dataManager, title: "ugly-filename", duration: 100)
    sut.getLibraryReference().addToItems(book)
    sut.dataManager.saveContext()
    try sut.moveItems(
      [LibraryItemRef(relativePath: book.relativePath, uuid: book.uuid)],
      inside: folder.relativePath
    )

    let presentation = sut.listeningHistoryPresentation(
      for: book.relativePath,
      fallbackTitle: book.title
    )
    let session = sut.startListeningSession(
      relativePath: book.relativePath,
      title: presentation.title,
      subtitle: presentation.subtitle,
      artworkRelativePath: presentation.artworkRelativePath
    )

    XCTAssertEqual(session.itemTitle, "Podcasts")
    XCTAssertEqual(session.subtitle, presentation.subtitle)
    XCTAssertEqual(session.artworkRelativePath, presentation.artworkRelativePath)
    XCTAssertEqual(session.relativePath, book.relativePath)
    XCTAssertEqual(session.presentation.title, "Podcasts")
  }
}
