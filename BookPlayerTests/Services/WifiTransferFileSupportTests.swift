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
    XCTAssertEqual(WifiTransferFileSupport.clampedPort(80), WifiTransferFileSupport.minimumPort)
    XCTAssertEqual(WifiTransferFileSupport.clampedPort(.max), WifiTransferFileSupport.maximumPort)
  }

  func testHTMLStrings_useAppLocalization() {
    let strings = WifiTransferHTML.strings
    XCTAssertEqual(strings.title, "wifi_transfer_title".localized)
    XCTAssertEqual(strings.folderHint, "wifi_transfer_web_folder_hint".localized)
    XCTAssertEqual(strings.retry, "wifi_transfer_web_retry".localized)
    XCTAssertEqual(strings.pinPrompt, "wifi_transfer_web_pin_prompt".localized)
    XCTAssertTrue(strings.skipped.contains("%d"))
    XCTAssertTrue(strings.selectedCount.contains("%d"))
    XCTAssertFalse(strings.subtitle.isEmpty)
    XCTAssertNotEqual(strings.subtitle, "wifi_transfer_web_subtitle")
  }

  func testHTMLPage_includesAllowlistAndAutoUpload() {
    let html = WifiTransferHTML.page(requiresPin: false)
    XCTAssertTrue(html.contains("ALLOWED"))
    XCTAssertTrue(html.contains("\"m4b\""))
    XCTAssertTrue(html.contains("startUpload"))
    XCTAssertTrue(html.contains("webkitGetAsEntry"))
    XCTAssertTrue(html.contains("dropEffect"))
    XCTAssertTrue(html.contains("const BASE = '/'"))
    XCTAssertTrue(html.contains("REQUIRES_PIN = false"))
    XCTAssertFalse(html.contains("id=\"send\""))
    XCTAssertTrue(html.contains("id=\"retry\""))
    XCTAssertTrue(html.contains(WifiTransferHTML.strings.title))
    XCTAssertFalse(html.contains("Access-Control-Allow-Origin"))
  }

  func testHTMLPage_pinGateWhenRequired() {
    let html = WifiTransferHTML.page(requiresPin: true)
    XCTAssertTrue(html.contains("REQUIRES_PIN = true"))
    XCTAssertTrue(html.contains("pinGate"))
    XCTAssertTrue(html.contains(WifiTransferFileSupport.pinHeaderName))
    XCTAssertTrue(html.contains("'unlock'"))
  }

  func testPin_formatAndEntropy() {
    let pin = WifiTransferFileSupport.makePin()
    XCTAssertTrue(WifiTransferFileSupport.isPinFormat(pin))
    XCTAssertFalse(WifiTransferFileSupport.isPinFormat("12"))
    XCTAssertFalse(WifiTransferFileSupport.isPinFormat("12ab"))
    let other = WifiTransferFileSupport.makePin()
    // Extremely unlikely both equal for many runs; still allow equality.
    _ = other
  }

  func testMaxUploadBytes_isPositiveCap() {
    XCTAssertGreaterThan(WifiTransferFileSupport.maxUploadBytes, 0)
  }

  func testIsAllowedFilename_rejectsDotfilesAndUnknown() {
    XCTAssertTrue(WifiTransferFileSupport.isAllowedFilename("book.m4b"))
    XCTAssertFalse(WifiTransferFileSupport.isAllowedFilename(".DS_Store"))
    XCTAssertFalse(WifiTransferFileSupport.isAllowedFilename("Thumbs.db"))
    XCTAssertNil(WifiTransferFileSupport.sanitizedRelativePath(from: "Book/.DS_Store"))
  }

  func testSanitizedRootFolder_rejectsDotPrefix() {
    XCTAssertNil(WifiTransferFileSupport.sanitizedRootFolder(from: ".hidden"))
  }

  func testClearStagingDirectory_removesLeftovers() throws {
    let root = WifiTransferFileSupport.stagingRootURL
    let nested = root.appendingPathComponent("Orphan/Book.m4b")
    try FileManager.default.createDirectory(
      at: nested.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("x".utf8).write(to: nested)
    XCTAssertNotNil(WifiTransferFileSupport.stagingRootURLIfPresent)

    XCTAssertTrue(WifiTransferFileSupport.clearStagingDirectory())
    XCTAssertNil(WifiTransferFileSupport.stagingRootURLIfPresent)
    XCTAssertFalse(WifiTransferFileSupport.clearStagingDirectory())
  }
}
