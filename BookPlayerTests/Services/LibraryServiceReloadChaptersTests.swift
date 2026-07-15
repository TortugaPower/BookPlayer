//
//  LibraryServiceReloadChaptersTests.swift
//  BookPlayerTests
//
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import CoreData
@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

/// Test double so we can control what the manual parser "finds" without a real audio file.
private final class StubAudioMetadataService: AudioMetadataServiceProtocol {
  var manualChaptersResult: [ChapterMetadata]?
  private(set) var extractManualChaptersCallCount = 0

  func extractMetadata(from fileURL: URL) async -> AudioMetadata? { nil }
  func extractMetadata(from asset: AVAsset) async -> AudioMetadata? { nil }
  func extractManualChapters(from fileURL: URL) async -> [ChapterMetadata]? {
    extractManualChaptersCallCount += 1
    return manualChaptersResult
  }
}

final class LibraryServiceReloadChaptersTests: XCTestCase {
  // swiftlint:disable force_cast
  private var sut: LibraryService!
  private var metadataStub: StubAudioMetadataService!

  override func setUp() {
    super.setUp()
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    metadataStub = StubAudioMetadataService()
    sut = LibraryService()
    sut.setup(dataManager: dataManager, audioMetadataService: metadataStub)
    _ = sut.getLibrary()
  }

  private func makeChapters(_ count: Int) -> [ChapterMetadata] {
    (0..<count).map { index in
      ChapterMetadata(
        title: "Chapter \(index + 1)",
        start: Double(index) * 10,
        duration: 10,
        index: index + 1
      )
    }
  }

  @discardableResult
  private func makeBook(title: String, existingChapters: Int) -> Book {
    let book = StubFactory.book(dataManager: sut.dataManager, title: title, duration: 100)
    sut.getLibraryReference().addToItems(book)
    for index in 0..<existingChapters {
      let chapter = StubFactory.chapter(dataManager: sut.dataManager, index: Int16(index + 1))
      book.addToChapters(chapter)
    }
    sut.dataManager.saveContext()
    return book
  }

  func testReloadChapters_findsMore_replacesAndReturnsNewCount() async throws {
    let relativePath = makeBook(title: "more", existingChapters: 1).relativePath!
    metadataStub.manualChaptersResult = makeChapters(4)

    let result = await sut.reloadChapters(relativePath: relativePath)

    XCTAssertEqual(result, 4)
    XCTAssertEqual(sut.getChapters(from: relativePath)?.count, 4)
  }

  func testReloadChapters_notMoreThanExisting_keepsExistingAndReturnsNil() async throws {
    let relativePath = makeBook(title: "same", existingChapters: 4).relativePath!
    metadataStub.manualChaptersResult = makeChapters(4)

    let result = await sut.reloadChapters(relativePath: relativePath)

    XCTAssertNil(result)
    XCTAssertEqual(sut.getChapters(from: relativePath)?.count, 4)
  }

  func testReloadChapters_emptyParseResult_returnsNil() async throws {
    let relativePath = makeBook(title: "empty", existingChapters: 1).relativePath!
    metadataStub.manualChaptersResult = []

    let result = await sut.reloadChapters(relativePath: relativePath)

    XCTAssertNil(result)
  }

  func testReloadChapters_fileMissing_returnsNilWithoutParsing() async throws {
    let relativePath = makeBook(title: "missing", existingChapters: 1).relativePath!
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)
    try? FileManager.default.removeItem(at: fileURL)
    metadataStub.manualChaptersResult = makeChapters(4)

    let result = await sut.reloadChapters(relativePath: relativePath)

    XCTAssertNil(result)
    XCTAssertEqual(metadataStub.extractManualChaptersCallCount, 0)
  }
  // swiftlint:enable force_cast
}
