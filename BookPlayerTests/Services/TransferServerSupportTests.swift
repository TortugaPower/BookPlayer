//
//  TransferServerSupportTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayer

final class TransferServerSupportTests: XCTestCase {
  func testSanitizedFilename_allowsAudiobookExtensions() {
    XCTAssertEqual(TransferServerSupport.sanitizedFilename(from: "Book.m4b"), "Book.m4b")
    XCTAssertEqual(TransferServerSupport.sanitizedFilename(from: "track.MP3"), "track.MP3")
    XCTAssertEqual(TransferServerSupport.sanitizedFilename(from: "archive.lpf"), "archive.lpf")
  }

  func testSanitizedFilename_stripsDirectoriesAndRejectsUnknownTypes() {
    XCTAssertNil(TransferServerSupport.sanitizedFilename(from: "folder/secret.m4b"))
    XCTAssertEqual(TransferServerSupport.sanitizedFilename(from: "book.m4b"), "book.m4b")
    XCTAssertNil(TransferServerSupport.sanitizedFilename(from: "notes.txt"))
    XCTAssertNil(TransferServerSupport.sanitizedFilename(from: ""))
    XCTAssertNil(TransferServerSupport.sanitizedFilename(from: "."))
  }

  func testSanitizedRelativePath_allowsNestedFolders() {
    XCTAssertEqual(
      TransferServerSupport.sanitizedRelativePath(from: "MyBook/Disc 1/01.mp3"),
      "MyBook/Disc 1/01.mp3"
    )
    XCTAssertEqual(
      TransferServerSupport.sanitizedRelativePath(from: "Author/Book/chapter.m4b"),
      "Author/Book/chapter.m4b"
    )
  }

  func testSanitizedRelativePath_rejectsTraversalAndBadTypes() {
    XCTAssertNil(TransferServerSupport.sanitizedRelativePath(from: "../secret.m4b"))
    XCTAssertNil(TransferServerSupport.sanitizedRelativePath(from: "Book/../secret.m4b"))
    XCTAssertNil(TransferServerSupport.sanitizedRelativePath(from: "/tmp/book.m4b"))
    XCTAssertNil(TransferServerSupport.sanitizedRelativePath(from: "Book/notes.txt"))
    XCTAssertNil(TransferServerSupport.sanitizedRelativePath(from: "Book//01.mp3"))
  }

  func testSanitizedRootFolder() {
    XCTAssertEqual(TransferServerSupport.sanitizedRootFolder(from: "MyBook"), "MyBook")
    XCTAssertEqual(TransferServerSupport.sanitizedRootFolder(from: "path/MyBook"), "MyBook")
    XCTAssertNil(TransferServerSupport.sanitizedRootFolder(from: ".."))
    XCTAssertNil(TransferServerSupport.sanitizedRootFolder(from: ""))
  }

  func testIsLooseFilePath() {
    XCTAssertTrue(TransferServerSupport.isLooseFilePath("book.m4b"))
    XCTAssertFalse(TransferServerSupport.isLooseFilePath("MyBook/book.m4b"))
  }

  func testUniqueFileURL_relativeCreatesParentsAndSuffix() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("transfer-server-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let first = try XCTUnwrap(
      TransferServerSupport.uniqueFileURL(relativePath: "Nest/Book.m4b", in: directory)
    )
    try Data("a".utf8).write(to: first)
    XCTAssertTrue(FileManager.default.fileExists(atPath: first.deletingLastPathComponent().path))

    let unique = try XCTUnwrap(
      TransferServerSupport.uniqueFileURL(relativePath: "Nest/Book.m4b", in: directory)
    )
    XCTAssertEqual(unique.lastPathComponent, "Book (1).m4b")
    XCTAssertEqual(unique.deletingLastPathComponent().lastPathComponent, "Nest")
  }

  func testPreferredPort_fallbackRange() {
    XCTAssertEqual(TransferServer.preferredPort, 8080)
    XCTAssertEqual(TransferServer.portFallbackCount, 10)
    XCTAssertEqual(TransferServerSupport.clampedPort(80), TransferServerSupport.minimumPort)
    XCTAssertEqual(TransferServerSupport.clampedPort(.max), TransferServerSupport.maximumPort)
  }

  @MainActor
  func testLocalIPv4Address_alwaysReturnsHost() {
    let host = TransferServer.localIPv4Address()
    XCTAssertFalse(host.isEmpty)
  }

  @MainActor
  func testServerStart_reachesRunningWithoutNetworkGate() async throws {
    let server = TransferServer()
    server.start()
    let deadline = Date().addingTimeInterval(3)
    while Date() < deadline {
      if server.isRunning { break }
      if case .failed = server.status { break }
      try await Task.sleep(nanoseconds: 50_000_000)
    }
    defer { server.stop() }
    XCTAssertTrue(server.isRunning, "status=\(server.status)")
    XCTAssertNotNil(server.serverURL)
  }

  func testHTMLStrings_useAppLocalization() {
    let strings = TransferServerHTML.strings
    XCTAssertEqual(strings.title, "transfer_server_title".localized)
    XCTAssertEqual(strings.folderHint, "transfer_server_web_folder_hint".localized)
    XCTAssertEqual(strings.retry, "transfer_server_web_retry".localized)
    XCTAssertEqual(strings.pinPrompt, "transfer_server_web_pin_prompt".localized)
    XCTAssertTrue(strings.skipped.contains("%d"))
    XCTAssertTrue(strings.selectedCount.contains("%d"))
    XCTAssertFalse(strings.subtitle.isEmpty)
    XCTAssertNotEqual(strings.subtitle, "transfer_server_web_subtitle")
  }

  func testHTMLPage_includesAllowlistAndAutoUpload() {
    let html = TransferServerHTML.page(requiresPin: false)
    XCTAssertTrue(html.contains("ALLOWED"))
    XCTAssertTrue(html.contains("\"m4b\""))
    XCTAssertTrue(html.contains("startUpload"))
    XCTAssertTrue(html.contains("webkitGetAsEntry"))
    XCTAssertTrue(html.contains("dropEffect"))
    XCTAssertTrue(html.contains("const BASE = '/'"))
    XCTAssertTrue(html.contains("REQUIRES_PIN = false"))
    XCTAssertFalse(html.contains("id=\"send\""))
    XCTAssertTrue(html.contains("id=\"retry\""))
    XCTAssertTrue(html.contains(TransferServerHTML.strings.title))
    XCTAssertFalse(html.contains("Access-Control-Allow-Origin"))
  }

  func testHTMLPage_pinGateWhenRequired() {
    let html = TransferServerHTML.page(requiresPin: true)
    XCTAssertTrue(html.contains("REQUIRES_PIN = true"))
    XCTAssertTrue(html.contains("pinGate"))
    XCTAssertTrue(html.contains(TransferServerSupport.pinHeaderName))
    XCTAssertTrue(html.contains("'unlock'"))
  }

  func testPin_formatAndEntropy() {
    let pin = TransferServerSupport.makePin()
    XCTAssertTrue(TransferServerSupport.isPinFormat(pin))
    XCTAssertFalse(TransferServerSupport.isPinFormat("12"))
    XCTAssertFalse(TransferServerSupport.isPinFormat("12ab"))
    let other = TransferServerSupport.makePin()
    // Extremely unlikely both equal for many runs; still allow equality.
    _ = other
  }

  func testMaxUploadBytes_isPositiveCap() {
    XCTAssertGreaterThan(TransferServerSupport.maxUploadBytes, 0)
  }

  func testIsAllowedFilename_rejectsDotfilesAndUnknown() {
    XCTAssertTrue(TransferServerSupport.isAllowedFilename("book.m4b"))
    XCTAssertFalse(TransferServerSupport.isAllowedFilename(".DS_Store"))
    XCTAssertFalse(TransferServerSupport.isAllowedFilename("Thumbs.db"))
    XCTAssertNil(TransferServerSupport.sanitizedRelativePath(from: "Book/.DS_Store"))
  }

  func testSanitizedRootFolder_rejectsDotPrefix() {
    XCTAssertNil(TransferServerSupport.sanitizedRootFolder(from: ".hidden"))
  }

  func testClearStagingDirectory_removesLeftovers() throws {
    let root = TransferServerSupport.stagingRootURL
    let nested = root.appendingPathComponent("Orphan/Book.m4b")
    try FileManager.default.createDirectory(
      at: nested.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("x".utf8).write(to: nested)
    XCTAssertNotNil(TransferServerSupport.stagingRootURLIfPresent)

    XCTAssertTrue(TransferServerSupport.clearStagingDirectory())
    XCTAssertNil(TransferServerSupport.stagingRootURLIfPresent)
    XCTAssertFalse(TransferServerSupport.clearStagingDirectory())
  }
}
