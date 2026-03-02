//
//  TranscriptImporterTests.swift
//  BookPlayerTests
//
//  Created for synchronized text viewer feature testing.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import XCTest
import UIKit
@testable import BookPlayer
@testable import BookPlayerKit

/// Tests for TranscriptImporter functionality
class TranscriptImporterTests: XCTestCase {
  
  var sut: TranscriptImporter!
  var mockViewController: UIViewController!
  
  override func setUp() {
    super.setUp()
    mockViewController = UIViewController()
    sut = TranscriptImporter(presentingViewController: mockViewController)
    
    // Clean up test files
    cleanupTestFiles()
  }
  
  override func tearDown() {
    cleanupTestFiles()
    sut = nil
    mockViewController = nil
    super.tearDown()
  }
  
  /// Clean up test LRC files
  private func cleanupTestFiles() {
    let processedURL = DataManager.getProcessedFolderURL()
    let lrcDirectory = processedURL.appendingPathComponent("lrc", isDirectory: true)
    
    if FileManager.default.fileExists(atPath: lrcDirectory.path) {
      try? FileManager.default.removeItem(at: lrcDirectory)
    }
  }
  
  // MARK: - Initialization Tests
  
  /// Test TranscriptImporter initializes correctly
  func testInitialization() {
    XCTAssertNotNil(sut)
  }
  
  // MARK: - Error Handling Tests
  
  /// Test TranscriptImporterError descriptions
  func testErrorDescriptions() {
    let errors: [TranscriptImporterError] = [
      .noViewController,
      .invalidState,
      .accessDenied,
      .noFileSelected,
      .cancelled,
      .importFailed(NSError(domain: "test", code: 1, userInfo: nil))
    ]
    
    for error in errors {
      XCTAssertNotNil(error.errorDescription)
      XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }
  }
  
  /// Test error types conform to Error protocol
  func testErrorTypesConformToErrorProtocol() {
    // TranscriptImporterError conforms to Error and LocalizedError
    let error: Error = TranscriptImporterError.noViewController
    XCTAssertNotNil(error)
    XCTAssertNotNil((error as? TranscriptImporterError)?.errorDescription)
  }
  
  // MARK: - Integration Tests with LRCService
  
  /// Test that successfully imported file can be loaded by LRCService
  func testImportedFileCanBeLoaded() throws {
    let relativePath = "books/integration_test.mp3"
    
    // Create a valid LRC file
    let tempDirectory = FileManager.default.temporaryDirectory
    let sourceURL = tempDirectory.appendingPathComponent("integration.lrc")
    
    let content = """
    [ti:Integration Test]
    [ar:Test Author]
    [00:10.00]First line
    [00:20.00]Second line
    """
    
    try content.write(to: sourceURL, atomically: true, encoding: .utf8)
    
    defer {
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    // Directly import using LRCService to test integration
    try LRCService.shared.importLRCFile(from: sourceURL, for: relativePath)
    
    // Verify the file can be loaded
    XCTAssertTrue(LRCService.shared.hasLRCFile(for: relativePath))
    
    let document = LRCService.shared.loadLRCDocument(for: relativePath)
    XCTAssertNotNil(document)
    XCTAssertEqual(document?.metadata.title, "Integration Test")
    XCTAssertEqual(document?.lines.count, 2)
    
    // Clean up
    LRCService.shared.deleteLRCFile(for: relativePath)
  }
  
  /// Test importing invalid file fails appropriately
  func testImportInvalidFileFails() throws {
    let relativePath = "books/invalid_test.mp3"
    
    // Create an invalid LRC file (empty)
    let tempDirectory = FileManager.default.temporaryDirectory
    let sourceURL = tempDirectory.appendingPathComponent("invalid.lrc")
    
    let content = ""
    try content.write(to: sourceURL, atomically: true, encoding: .utf8)
    
    defer {
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    // Attempt to import should fail
    XCTAssertThrowsError(try LRCService.shared.importLRCFile(from: sourceURL, for: relativePath))
    
    // Verify no file was created
    XCTAssertFalse(LRCService.shared.hasLRCFile(for: relativePath))
  }
  
  /// Test importing file with only metadata fails
  func testImportFileWithOnlyMetadataFails() throws {
    let relativePath = "books/metadata_only.mp3"
    
    let tempDirectory = FileManager.default.temporaryDirectory
    let sourceURL = tempDirectory.appendingPathComponent("metadata_only.lrc")
    
    let content = """
    [ti:Title Only]
    [ar:Artist Only]
    """
    
    try content.write(to: sourceURL, atomically: true, encoding: .utf8)
    
    defer {
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    // Should fail because no valid lines
    XCTAssertThrowsError(try LRCService.shared.importLRCFile(from: sourceURL, for: relativePath))
    
    XCTAssertFalse(LRCService.shared.hasLRCFile(for: relativePath))
  }
  
  // MARK: - Multiple Import Tests
  
  /// Test importing multiple files for different items
  func testImportMultipleFiles() throws {
    let items = [
      ("books/book1.mp3", "Book 1"),
      ("books/book2.mp3", "Book 2"),
      ("books/book3.mp3", "Book 3")
    ]
    
    let tempDirectory = FileManager.default.temporaryDirectory
    
    for (index, item) in items.enumerated() {
      let sourceURL = tempDirectory.appendingPathComponent("test\(index).lrc")
      let content = """
      [ti:\(item.1)]
      [00:10.00]Line from \(item.1)
      """
      
      try content.write(to: sourceURL, atomically: true, encoding: .utf8)
      try LRCService.shared.importLRCFile(from: sourceURL, for: item.0)
      
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    // Verify all files were imported correctly
    for (path, title) in items {
      XCTAssertTrue(LRCService.shared.hasLRCFile(for: path))
      
      let document = LRCService.shared.loadLRCDocument(for: path)
      XCTAssertNotNil(document)
      XCTAssertEqual(document?.metadata.title, title)
    }
    
    // Clean up
    for (path, _) in items {
      LRCService.shared.deleteLRCFile(for: path)
    }
  }
  
  /// Test overwriting existing transcript
  func testOverwriteExistingTranscript() throws {
    let relativePath = "books/overwrite_test.mp3"
    let tempDirectory = FileManager.default.temporaryDirectory
    
    // Import first file
    let firstURL = tempDirectory.appendingPathComponent("first.lrc")
    let firstContent = """
    [ti:First Version]
    [00:10.00]First line
    """
    
    try firstContent.write(to: firstURL, atomically: true, encoding: .utf8)
    try LRCService.shared.importLRCFile(from: firstURL, for: relativePath)
    try? FileManager.default.removeItem(at: firstURL)
    
    // Verify first import
    var document = LRCService.shared.loadLRCDocument(for: relativePath)
    XCTAssertEqual(document?.metadata.title, "First Version")
    
    // Import second file (overwrite)
    let secondURL = tempDirectory.appendingPathComponent("second.lrc")
    let secondContent = """
    [ti:Second Version]
    [00:20.00]Second line
    """
    
    try secondContent.write(to: secondURL, atomically: true, encoding: .utf8)
    try LRCService.shared.importLRCFile(from: secondURL, for: relativePath)
    try? FileManager.default.removeItem(at: secondURL)
    
    // Verify overwrite
    document = LRCService.shared.loadLRCDocument(for: relativePath)
    XCTAssertEqual(document?.metadata.title, "Second Version")
    XCTAssertEqual(document?.lines[0].text, "Second line")
    
    // Clean up
    LRCService.shared.deleteLRCFile(for: relativePath)
  }
  
  // MARK: - Edge Case Tests
  
  /// Test importing file with special characters in filename
  func testImportFileWithSpecialCharacters() throws {
    let relativePath = "books/special-characters_test (1).mp3"
    
    let tempDirectory = FileManager.default.temporaryDirectory
    let sourceURL = tempDirectory.appendingPathComponent("special.lrc")
    
    let content = """
    [ti:Special Characters Test]
    [00:10.00]Test line
    """
    
    try content.write(to: sourceURL, atomically: true, encoding: .utf8)
    
    defer {
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    XCTAssertNoThrow(try LRCService.shared.importLRCFile(from: sourceURL, for: relativePath))
    XCTAssertTrue(LRCService.shared.hasLRCFile(for: relativePath))
    
    // Clean up
    LRCService.shared.deleteLRCFile(for: relativePath)
  }
  
  /// Test importing file with long content
  func testImportFileWithLongContent() throws {
    let relativePath = "books/long_content.mp3"
    
    let tempDirectory = FileManager.default.temporaryDirectory
    let sourceURL = tempDirectory.appendingPathComponent("long.lrc")
    
    // Create file with many lines
    var content = "[ti:Long Content]\n"
    for i in 0..<100 {
      let minutes = i / 60
      let seconds = i % 60
      content += String(format: "[%02d:%02d.00]Line %d\n", minutes, seconds, i)
    }
    
    try content.write(to: sourceURL, atomically: true, encoding: .utf8)
    
    defer {
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    XCTAssertNoThrow(try LRCService.shared.importLRCFile(from: sourceURL, for: relativePath))
    
    let document = LRCService.shared.loadLRCDocument(for: relativePath)
    XCTAssertNotNil(document)
    XCTAssertEqual(document?.lines.count, 100)
    
    // Clean up
    LRCService.shared.deleteLRCFile(for: relativePath)
  }
  
  /// Test importing file with Unicode characters
  func testImportFileWithUnicodeContent() throws {
    let relativePath = "books/unicode.mp3"
    
    let tempDirectory = FileManager.default.temporaryDirectory
    let sourceURL = tempDirectory.appendingPathComponent("unicode.lrc")
    
    let content = """
    [ti:Unicode Test 测试 テスト]
    [ar:Artist 艺术家 アーティスト]
    [00:10.00]Hello 你好 こんにちは
    [00:20.00]World 世界 世界
    [00:30.00]Emoji test 😀🎵📖
    """
    
    try content.write(to: sourceURL, atomically: true, encoding: .utf8)
    
    defer {
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    XCTAssertNoThrow(try LRCService.shared.importLRCFile(from: sourceURL, for: relativePath))
    
    let document = LRCService.shared.loadLRCDocument(for: relativePath)
    XCTAssertNotNil(document)
    XCTAssertTrue(document?.metadata.title?.contains("测试") ?? false)
    XCTAssertTrue(document?.lines[0].text.contains("你好") ?? false)
    XCTAssertTrue(document?.lines[2].text.contains("😀") ?? false)
    
    // Clean up
    LRCService.shared.deleteLRCFile(for: relativePath)
  }
}
