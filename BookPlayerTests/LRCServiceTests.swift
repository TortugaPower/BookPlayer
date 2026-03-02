//
//  LRCServiceTests.swift
//  BookPlayerTests
//
//  Created for synchronized text viewer feature testing.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import XCTest
@testable import BookPlayer
@testable import BookPlayerKit

/// Tests for LRC file management service
class LRCServiceTests: XCTestCase {
  
  var sut: LRCService!
  var testLRCDirectory: URL!
  
  override func setUp() {
    super.setUp()
    sut = LRCService.shared
    
    // Clean up any existing test files
    cleanupTestFiles()
  }
  
  override func tearDown() {
    cleanupTestFiles()
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
  
  // MARK: - LRC File URL Tests
  
  /// Test getting LRC file URL for a given relative path
  func testGetLRCFileURL() {
    let relativePath = "books/mybook.mp3"
    let lrcURL = sut.getLRCFileURL(for: relativePath)
    
    XCTAssertTrue(lrcURL.path.contains("lrc"))
    XCTAssertTrue(lrcURL.lastPathComponent == "mybook.lrc")
  }
  
  /// Test getting LRC file URL with different file extensions
  func testGetLRCFileURLWithDifferentExtensions() {
    let mp3Path = "books/audiobook.mp3"
    let m4aPath = "books/audiobook.m4a"
    let m4bPath = "books/audiobook.m4b"
    
    let mp3LRCURL = sut.getLRCFileURL(for: mp3Path)
    let m4aLRCURL = sut.getLRCFileURL(for: m4aPath)
    let m4bLRCURL = sut.getLRCFileURL(for: m4bPath)
    
    XCTAssertEqual(mp3LRCURL.lastPathComponent, "audiobook.lrc")
    XCTAssertEqual(m4aLRCURL.lastPathComponent, "audiobook.lrc")
    XCTAssertEqual(m4bLRCURL.lastPathComponent, "audiobook.lrc")
  }
  
  /// Test getting LRC file URL with nested path
  func testGetLRCFileURLWithNestedPath() {
    let relativePath = "folder1/folder2/book.mp3"
    let lrcURL = sut.getLRCFileURL(for: relativePath)
    
    // Should only use the filename, not the full path
    XCTAssertEqual(lrcURL.lastPathComponent, "book.lrc")
  }
  
  // MARK: - Has LRC File Tests
  
  /// Test checking for non-existent LRC file
  func testHasLRCFileReturnsFalseWhenNoFile() {
    let relativePath = "books/nonexistent.mp3"
    
    XCTAssertFalse(sut.hasLRCFile(for: relativePath))
  }
  
  /// Test checking for existing LRC file
  func testHasLRCFileReturnsTrueWhenFileExists() throws {
    let relativePath = "books/existingbook.mp3"
    let lrcURL = sut.getLRCFileURL(for: relativePath)
    
    // Create the directory if needed
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    // Create a test LRC file
    let testContent = "[00:10.00]Test line"
    try testContent.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    XCTAssertTrue(sut.hasLRCFile(for: relativePath))
  }
  
  // MARK: - Import LRC File Tests
  
  /// Test importing a valid LRC file
  func testImportValidLRCFile() throws {
    // Create a temporary source LRC file
    let tempDirectory = FileManager.default.temporaryDirectory
    let sourceURL = tempDirectory.appendingPathComponent("source.lrc")
    
    let content = """
    [ti:Test Book]
    [ar:Test Author]
    [00:10.00]First line
    [00:20.00]Second line
    """
    
    try content.write(to: sourceURL, atomically: true, encoding: .utf8)
    
    defer {
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    let relativePath = "books/testbook.mp3"
    
    // Import the file
    XCTAssertNoThrow(try sut.importLRCFile(from: sourceURL, for: relativePath))
    
    // Verify the file was imported
    XCTAssertTrue(sut.hasLRCFile(for: relativePath))
    
    // Verify the content
    let document = sut.loadLRCDocument(for: relativePath)
    XCTAssertNotNil(document)
    XCTAssertEqual(document?.metadata.title, "Test Book")
    XCTAssertEqual(document?.lines.count, 2)
  }
  
  /// Test importing invalid LRC file throws error
  func testImportInvalidLRCFileThrowsError() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
    let sourceURL = tempDirectory.appendingPathComponent("invalid.lrc")
    
    // Create an invalid LRC file (only metadata, no lines)
    let content = """
    [ti:Invalid File]
    """
    
    try content.write(to: sourceURL, atomically: true, encoding: .utf8)
    
    defer {
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    let relativePath = "books/invalid.mp3"
    
    // Should throw an error because file has no valid lines
    XCTAssertThrowsError(try sut.importLRCFile(from: sourceURL, for: relativePath))
    
    // File should not be imported
    XCTAssertFalse(sut.hasLRCFile(for: relativePath))
  }
  
  /// Test importing overwrites existing file
  func testImportOverwritesExistingFile() throws {
    let relativePath = "books/overwrite.mp3"
    let lrcURL = sut.getLRCFileURL(for: relativePath)
    
    // Create directory
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    // Create initial file
    let initialContent = "[00:10.00]Initial line"
    try initialContent.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    XCTAssertTrue(sut.hasLRCFile(for: relativePath))
    
    // Create new source file
    let tempDirectory = FileManager.default.temporaryDirectory
    let sourceURL = tempDirectory.appendingPathComponent("new.lrc")
    let newContent = "[00:20.00]New line"
    try newContent.write(to: sourceURL, atomically: true, encoding: .utf8)
    
    defer {
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    // Import should overwrite
    XCTAssertNoThrow(try sut.importLRCFile(from: sourceURL, for: relativePath))
    
    // Verify new content
    let document = sut.loadLRCDocument(for: relativePath)
    XCTAssertEqual(document?.lines.count, 1)
    XCTAssertEqual(document?.lines[0].text, "New line")
  }
  
  /// Test importing from non-existent file
  func testImportFromNonExistentFile() {
    let nonExistentURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent.lrc")
    let relativePath = "books/test.mp3"
    
    XCTAssertThrowsError(try sut.importLRCFile(from: nonExistentURL, for: relativePath))
  }
  
  // MARK: - Load LRC Document Tests
  
  /// Test loading existing LRC document
  func testLoadLRCDocument() throws {
    let relativePath = "books/loadtest.mp3"
    let lrcURL = sut.getLRCFileURL(for: relativePath)
    
    // Create directory and file
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = """
    [ti:Load Test]
    [00:10.00]Line one
    [00:20.00]Line two
    [00:30.00]Line three
    """
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    let document = sut.loadLRCDocument(for: relativePath)
    
    XCTAssertNotNil(document)
    XCTAssertEqual(document?.metadata.title, "Load Test")
    XCTAssertEqual(document?.lines.count, 3)
    XCTAssertEqual(document?.lines[0].text, "Line one")
    XCTAssertEqual(document?.lines[1].text, "Line two")
    XCTAssertEqual(document?.lines[2].text, "Line three")
  }
  
  /// Test loading non-existent LRC document returns nil
  func testLoadNonExistentLRCDocument() {
    let relativePath = "books/nonexistent.mp3"
    
    let document = sut.loadLRCDocument(for: relativePath)
    
    XCTAssertNil(document)
  }
  
  /// Test loading corrupted LRC document returns nil
  func testLoadCorruptedLRCDocument() throws {
    let relativePath = "books/corrupted.mp3"
    let lrcURL = sut.getLRCFileURL(for: relativePath)
    
    // Create directory and corrupted file
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    // File exists but has no valid content
    let content = ""
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    let document = sut.loadLRCDocument(for: relativePath)
    
    // Should return nil for corrupted files
    XCTAssertNil(document)
  }
  
  // MARK: - Delete LRC File Tests
  
  /// Test deleting existing LRC file
  func testDeleteExistingLRCFile() throws {
    let relativePath = "books/deletetest.mp3"
    let lrcURL = sut.getLRCFileURL(for: relativePath)
    
    // Create directory and file
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = "[00:10.00]Test line"
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    XCTAssertTrue(sut.hasLRCFile(for: relativePath))
    
    // Delete the file
    sut.deleteLRCFile(for: relativePath)
    
    // Verify deletion
    XCTAssertFalse(sut.hasLRCFile(for: relativePath))
    XCTAssertFalse(FileManager.default.fileExists(atPath: lrcURL.path))
  }
  
  /// Test deleting non-existent LRC file does not throw error
  func testDeleteNonExistentLRCFile() {
    let relativePath = "books/nonexistent.mp3"
    
    // Should not throw error or crash
    XCTAssertNoThrow(sut.deleteLRCFile(for: relativePath))
  }
  
  // MARK: - Integration Tests
  
  /// Test complete workflow: import, load, delete
  func testCompleteWorkflow() throws {
    let relativePath = "books/workflow.mp3"
    
    // 1. Verify no file exists initially
    XCTAssertFalse(sut.hasLRCFile(for: relativePath))
    XCTAssertNil(sut.loadLRCDocument(for: relativePath))
    
    // 2. Create and import a file
    let tempDirectory = FileManager.default.temporaryDirectory
    let sourceURL = tempDirectory.appendingPathComponent("workflow.lrc")
    
    let content = """
    [ti:Workflow Test]
    [ar:Test Author]
    [00:10.00]First line
    [00:20.00]Second line
    [00:30.00]Third line
    """
    
    try content.write(to: sourceURL, atomically: true, encoding: .utf8)
    
    defer {
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    try sut.importLRCFile(from: sourceURL, for: relativePath)
    
    // 3. Verify file exists and can be loaded
    XCTAssertTrue(sut.hasLRCFile(for: relativePath))
    
    let document = sut.loadLRCDocument(for: relativePath)
    XCTAssertNotNil(document)
    XCTAssertEqual(document?.metadata.title, "Workflow Test")
    XCTAssertEqual(document?.lines.count, 3)
    
    // 4. Delete the file
    sut.deleteLRCFile(for: relativePath)
    
    // 5. Verify file is gone
    XCTAssertFalse(sut.hasLRCFile(for: relativePath))
    XCTAssertNil(sut.loadLRCDocument(for: relativePath))
  }
  
  /// Test handling multiple files simultaneously
  func testMultipleFiles() throws {
    let paths = [
      "books/book1.mp3",
      "books/book2.mp3",
      "books/book3.mp3"
    ]
    
    // Create temp directory
    let tempDirectory = FileManager.default.temporaryDirectory
    
    // Import files
    for (index, path) in paths.enumerated() {
      let sourceURL = tempDirectory.appendingPathComponent("source\(index).lrc")
      let content = "[00:10.00]Line for book \(index + 1)"
      try content.write(to: sourceURL, atomically: true, encoding: .utf8)
      
      try sut.importLRCFile(from: sourceURL, for: path)
      
      try? FileManager.default.removeItem(at: sourceURL)
    }
    
    // Verify all files exist
    for path in paths {
      XCTAssertTrue(sut.hasLRCFile(for: path))
    }
    
    // Verify each file has correct content
    for (index, path) in paths.enumerated() {
      let document = sut.loadLRCDocument(for: path)
      XCTAssertNotNil(document)
      XCTAssertEqual(document?.lines[0].text, "Line for book \(index + 1)")
    }
    
    // Clean up
    for path in paths {
      sut.deleteLRCFile(for: path)
    }
  }
}
