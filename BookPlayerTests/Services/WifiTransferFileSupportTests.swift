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
    // Basename only — never writes outside the staging directory
    XCTAssertEqual(WifiTransferFileSupport.sanitizedFilename(from: "../secret.m4b"), "secret.m4b")
    XCTAssertEqual(WifiTransferFileSupport.sanitizedFilename(from: "/tmp/book.m4b"), "book.m4b")
    XCTAssertNil(WifiTransferFileSupport.sanitizedFilename(from: "notes.txt"))
    XCTAssertNil(WifiTransferFileSupport.sanitizedFilename(from: ""))
    XCTAssertNil(WifiTransferFileSupport.sanitizedFilename(from: "."))
  }

  func testUniqueFileURL_addsSuffixWhenFileExists() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("wifi-transfer-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let first = directory.appendingPathComponent("Book.m4b")
    try Data("a".utf8).write(to: first)

    let unique = WifiTransferFileSupport.uniqueFileURL(filename: "Book.m4b", in: directory)
    XCTAssertEqual(unique.lastPathComponent, "Book (1).m4b")
    XCTAssertFalse(FileManager.default.fileExists(atPath: unique.path))
  }

  func testPreferredPort_fallbackRange() {
    XCTAssertEqual(WifiTransferServer.preferredPort, 8080)
    XCTAssertEqual(WifiTransferServer.portFallbackCount, 10)
  }
}
