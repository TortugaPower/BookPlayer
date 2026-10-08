//
//  WifiTransferFileSupportTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayer

final class WifiTransferFileSupportTests: XCTestCase {
  func testSanitizedFilename_allowsAudiobookExtensions() {
    XCTAssertEqual(WifiTransferFileSupport.sanitizedFilename(from: "Book.m4b"), "Book.m4b")
    XCTAssertEqual(WifiTransferFileSupport.sanitizedFilename(from: "track.MP3"), "track.MP3")
    XCTAssertEqual(WifiTransferFileSupport.sanitizedFilename(from: "archive.lpf"), "archive.lpf")
  }

  func testSanitizedFilename_stripsDirectoriesAndRejectsUnknownTypes() {
    XCTAssertNil(WifiTransferFileSupport.sanitizedFilename(from: "folder/secret.m4b"))
    XCTAssertEqual(WifiTransferFileSupport.sanitizedFilename(from: "book.m4b"), "book.m4b")
    XCTAssertNil(WifiTransferFileSupport.sanitizedFilename(from: "notes.txt"))
    XCTAssertNil(WifiTransferFileSupport.sanitizedFilename(from: ""))
    XCTAssertNil(WifiTransferFileSupport.sanitizedFilename(from: "."))
  }

  func testSanitizedRelativePath_allowsNestedFolders() {
    XCTAssertEqual(
      WifiTransferFileSupport.sanitizedRelativePath(from: "MyBook/Disc 1/01.mp3"),
      "MyBook/Disc 1/01.mp3"
    )
    XCTAssertEqual(
      WifiTransferFileSupport.sanitizedRelativePath(from: "Author/Book/chapter.m4b"),
      "Author/Book/chapter.m4b"
    )
  }

  func testSanitizedRelativePath_rejectsTraversalAndBadTypes() {
    XCTAssertNil(WifiTransferFileSupport.sanitizedRelativePath(from: "../secret.m4b"))
    XCTAssertNil(WifiTransferFileSupport.sanitizedRelativePath(from: "Book/../secret.m4b"))
    XCTAssertNil(WifiTransferFileSupport.sanitizedRelativePath(from: "/tmp/book.m4b"))
    XCTAssertNil(WifiTransferFileSupport.sanitizedRelativePath(from: "Book/notes.txt"))
    XCTAssertNil(WifiTransferFileSupport.sanitizedRelativePath(from: "Book//01.mp3"))
  }

  func testSanitizedRootFolder() {
    XCTAssertEqual(WifiTransferFileSupport.sanitizedRootFolder(from: "MyBook"), "MyBook")
    XCTAssertEqual(WifiTransferFileSupport.sanitizedRootFolder(from: "path/MyBook"), "MyBook")
    XCTAssertNil(WifiTransferFileSupport.sanitizedRootFolder(from: ".."))
    XCTAssertNil(WifiTransferFileSupport.sanitizedRootFolder(from: ""))
  }

  func testIsLooseFilePath() {
    XCTAssertTrue(WifiTransferFileSupport.isLooseFilePath("book.m4b"))
    XCTAssertFalse(WifiTransferFileSupport.isLooseFilePath("MyBook/book.m4b"))
  }

  func testUniqueFileURL_relativeCreatesParentsAndSuffix() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("wifi-transfer-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let first = try XCTUnwrap(
      WifiTransferFileSupport.uniqueFileURL(relativePath: "Nest/Book.m4b", in: directory)
    )
    try Data("a".utf8).write(to: first)
    XCTAssertTrue(FileManager.default.fileExists(atPath: first.deletingLastPathComponent().path))

    let unique = try XCTUnwrap(
      WifiTransferFileSupport.uniqueFileURL(relativePath: "Nest/Book.m4b", in: directory)
    )
    XCTAssertEqual(unique.lastPathComponent, "Book (1).m4b")
    XCTAssertEqual(unique.deletingLastPathComponent().lastPathComponent, "Nest")
  }

  func testPreferredPort_fallbackRange() {
    XCTAssertEqual(WifiTransferServer.preferredPort, 8080)
    XCTAssertEqual(WifiTransferServer.portFallbackCount, 10)
  }

  func testHTMLStrings_russianLocale() {
    let ru = WifiTransferHTML.strings(for: "ru")
    XCTAssertTrue(ru.folderHint.contains("структура") || ru.folderHint.lowercased().contains("папк"))
    let en = WifiTransferHTML.strings(for: "en")
    XCTAssertTrue(en.folderHint.lowercased().contains("structure"))
  }
}
