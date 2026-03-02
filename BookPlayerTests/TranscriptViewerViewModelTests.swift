//
//  TranscriptViewerViewModelTests.swift
//  BookPlayerTests
//
//  Created for synchronized text viewer feature testing.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import XCTest
import Combine
@testable import BookPlayer
@testable import BookPlayerKit

/// Tests for TranscriptViewerViewModel functionality
class TranscriptViewerViewModelTests: XCTestCase {
  
  var sut: TranscriptViewerViewModel!
  var cancellables: Set<AnyCancellable>!
  
  override func setUp() {
    super.setUp()
    sut = TranscriptViewerViewModel()
    cancellables = Set<AnyCancellable>()
    
    // Clean up test files
    cleanupTestFiles()
  }
  
  override func tearDown() {
    cleanupTestFiles()
    cancellables = nil
    sut = nil
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
  
  /// Test ViewModel initializes with nil document
  func testInitialState() {
    XCTAssertNil(sut.lrcDocument)
    XCTAssertNil(sut.currentLineIndex)
    XCTAssertEqual(sut.currentTime, 0)
    XCTAssertFalse(sut.hasTranscript)
    XCTAssertTrue(sut.lines.isEmpty)
  }
  
  // MARK: - Load Transcript Tests
  
  /// Test loading a valid transcript
  func testLoadValidTranscript() throws {
    let relativePath = "books/test.mp3"
    
    // Create a test LRC file
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = """
    [ti:Test Book]
    [ar:Test Author]
    [00:10.00]First line
    [00:20.00]Second line
    [00:30.00]Third line
    """
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    // Load the transcript
    sut.loadTranscript(for: relativePath)
    
    // Verify loading
    XCTAssertNotNil(sut.lrcDocument)
    XCTAssertTrue(sut.hasTranscript)
    XCTAssertEqual(sut.lines.count, 3)
    XCTAssertEqual(sut.lrcDocument?.metadata.title, "Test Book")
  }
  
  /// Test loading non-existent transcript
  func testLoadNonExistentTranscript() {
    let relativePath = "books/nonexistent.mp3"
    
    sut.loadTranscript(for: relativePath)
    
    XCTAssertNil(sut.lrcDocument)
    XCTAssertFalse(sut.hasTranscript)
    XCTAssertTrue(sut.lines.isEmpty)
  }
  
  /// Test hasTranscript check before loading
  func testHasTranscriptCheck() throws {
    let relativePath = "books/check.mp3"
    
    // Initially no transcript
    XCTAssertFalse(sut.hasTranscript(for: relativePath))
    
    // Create a transcript file
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = "[00:10.00]Test line"
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    // Now should have transcript
    XCTAssertTrue(sut.hasTranscript(for: relativePath))
  }
  
  // MARK: - Update Current Time Tests
  
  /// Test updating current time without document
  func testUpdateCurrentTimeWithoutDocument() {
    sut.updateCurrentTime(10.0)
    
    XCTAssertEqual(sut.currentTime, 10.0)
    XCTAssertNil(sut.currentLineIndex)
  }
  
  /// Test updating current time with document
  func testUpdateCurrentTimeWithDocument() {
    // Create a mock document
    let lines = [
      LRCLine(timestamp: 10.0, text: "First line"),
      LRCLine(timestamp: 20.0, text: "Second line"),
      LRCLine(timestamp: 30.0, text: "Third line")
    ]
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    sut.lrcDocument = document
    
    // Update to first line
    sut.updateCurrentTime(10.0)
    XCTAssertEqual(sut.currentLineIndex, 0)
    
    // Update to between first and second
    sut.updateCurrentTime(15.0)
    XCTAssertEqual(sut.currentLineIndex, 0)
    
    // Update to second line
    sut.updateCurrentTime(20.0)
    XCTAssertEqual(sut.currentLineIndex, 1)
    
    // Update to third line
    sut.updateCurrentTime(30.0)
    XCTAssertEqual(sut.currentLineIndex, 2)
    
    // Update past last line
    sut.updateCurrentTime(40.0)
    XCTAssertEqual(sut.currentLineIndex, 2)
  }
  
  /// Test updating current time before first line
  func testUpdateCurrentTimeBeforeFirstLine() {
    let lines = [
      LRCLine(timestamp: 10.0, text: "First line"),
      LRCLine(timestamp: 20.0, text: "Second line")
    ]
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    sut.lrcDocument = document
    
    // Update to before first line
    sut.updateCurrentTime(5.0)
    XCTAssertNil(sut.currentLineIndex)
  }
  
  /// Test updating current time triggers published property
  func testUpdateCurrentTimeTriggersPublisher() {
    let expectation = self.expectation(description: "Current time updated")
    
    let lines = [
      LRCLine(timestamp: 10.0, text: "First line"),
      LRCLine(timestamp: 20.0, text: "Second line")
    ]
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    sut.lrcDocument = document
    
    // Subscribe to currentLineIndex changes
    sut.$currentLineIndex
      .dropFirst() // Skip initial value
      .sink { index in
        XCTAssertEqual(index, 0)
        expectation.fulfill()
      }
      .store(in: &cancellables)
    
    sut.updateCurrentTime(15.0)
    
    waitForExpectations(timeout: 1.0)
  }
  
  // MARK: - Clear Transcript Tests
  
  /// Test clearing transcript
  func testClearTranscript() {
    // Set up a document first
    let lines = [LRCLine(timestamp: 10.0, text: "Test")]
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    sut.lrcDocument = document
    sut.updateCurrentTime(15.0)
    
    XCTAssertNotNil(sut.lrcDocument)
    XCTAssertNotNil(sut.currentLineIndex)
    
    // Clear
    sut.clearTranscript()
    
    XCTAssertNil(sut.lrcDocument)
    XCTAssertNil(sut.currentLineIndex)
    XCTAssertFalse(sut.hasTranscript)
    XCTAssertTrue(sut.lines.isEmpty)
  }
  
  // MARK: - Lines Property Tests
  
  /// Test lines property returns empty array when no document
  func testLinesPropertyWhenNoDocument() {
    XCTAssertTrue(sut.lines.isEmpty)
  }
  
  /// Test lines property returns document lines
  func testLinesPropertyWithDocument() {
    let lines = [
      LRCLine(timestamp: 10.0, text: "First"),
      LRCLine(timestamp: 20.0, text: "Second"),
      LRCLine(timestamp: 30.0, text: "Third")
    ]
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    sut.lrcDocument = document
    
    XCTAssertEqual(sut.lines.count, 3)
    XCTAssertEqual(sut.lines[0].text, "First")
    XCTAssertEqual(sut.lines[1].text, "Second")
    XCTAssertEqual(sut.lines[2].text, "Third")
  }
  
  // MARK: - Has Transcript Property Tests
  
  /// Test hasTranscript property
  func testHasTranscriptProperty() {
    // Initially false
    XCTAssertFalse(sut.hasTranscript)
    
    // Set document
    let lines = [LRCLine(timestamp: 10.0, text: "Test")]
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    sut.lrcDocument = document
    
    // Now true
    XCTAssertTrue(sut.hasTranscript)
    
    // Clear
    sut.clearTranscript()
    
    // False again
    XCTAssertFalse(sut.hasTranscript)
  }
  
  // MARK: - Integration Tests
  
  /// Test complete workflow: load, update, clear
  func testCompleteWorkflow() throws {
    let relativePath = "books/workflow.mp3"
    
    // Create transcript file
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = """
    [ti:Workflow Test]
    [00:05.00]Line 0
    [00:10.00]Line 1
    [00:20.00]Line 2
    [00:30.00]Line 3
    """
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    // 1. Load transcript
    sut.loadTranscript(for: relativePath)
    XCTAssertTrue(sut.hasTranscript)
    XCTAssertEqual(sut.lines.count, 4)
    
    // 2. Update time to first line
    sut.updateCurrentTime(5.0)
    XCTAssertEqual(sut.currentLineIndex, 0)
    
    // 3. Update time to second line
    sut.updateCurrentTime(15.0)
    XCTAssertEqual(sut.currentLineIndex, 1)
    
    // 4. Update time to third line
    sut.updateCurrentTime(25.0)
    XCTAssertEqual(sut.currentLineIndex, 2)
    
    // 5. Clear transcript
    sut.clearTranscript()
    XCTAssertFalse(sut.hasTranscript)
    XCTAssertNil(sut.currentLineIndex)
  }
  
  /// Test switching between different transcripts
  func testSwitchingTranscripts() throws {
    let path1 = "books/book1.mp3"
    let path2 = "books/book2.mp3"
    
    // Create two transcript files
    for (path, title) in [(path1, "Book 1"), (path2, "Book 2")] {
      let lrcURL = LRCService.shared.getLRCFileURL(for: path)
      try FileManager.default.createDirectory(
        at: lrcURL.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: nil
      )
      
      let content = """
      [ti:\(title)]
      [00:10.00]Line from \(title)
      """
      
      try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    }
    
    // Load first transcript
    sut.loadTranscript(for: path1)
    XCTAssertEqual(sut.lrcDocument?.metadata.title, "Book 1")
    
    // Switch to second transcript
    sut.loadTranscript(for: path2)
    XCTAssertEqual(sut.lrcDocument?.metadata.title, "Book 2")
    
    // Current line index should be reset
    XCTAssertNil(sut.currentLineIndex)
  }
  
  /// Test rapid time updates
  func testRapidTimeUpdates() {
    let lines = [
      LRCLine(timestamp: 0.0, text: "Line 0"),
      LRCLine(timestamp: 1.0, text: "Line 1"),
      LRCLine(timestamp: 2.0, text: "Line 2"),
      LRCLine(timestamp: 3.0, text: "Line 3"),
      LRCLine(timestamp: 4.0, text: "Line 4")
    ]
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    sut.lrcDocument = document
    
    // Simulate rapid time updates
    for i in 0..<50 {
      let time = Double(i) * 0.1
      sut.updateCurrentTime(time)
    }
    
    // Should end up at last line
    XCTAssertEqual(sut.currentLineIndex, 4)
  }
  
  /// Test with document containing single line
  func testSingleLineDocument() {
    let lines = [LRCLine(timestamp: 10.0, text: "Only line")]
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    sut.lrcDocument = document
    
    // Before the line
    sut.updateCurrentTime(5.0)
    XCTAssertNil(sut.currentLineIndex)
    
    // At the line
    sut.updateCurrentTime(10.0)
    XCTAssertEqual(sut.currentLineIndex, 0)
    
    // After the line
    sut.updateCurrentTime(20.0)
    XCTAssertEqual(sut.currentLineIndex, 0)
  }
  
  /// Test with document containing many lines
  func testManyLinesDocument() {
    var lines: [LRCLine] = []
    for i in 0..<100 {
      lines.append(LRCLine(timestamp: Double(i), text: "Line \(i)"))
    }
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    sut.lrcDocument = document
    
    // Test at various positions
    sut.updateCurrentTime(25.5)
    XCTAssertEqual(sut.currentLineIndex, 25)
    
    sut.updateCurrentTime(50.0)
    XCTAssertEqual(sut.currentLineIndex, 50)
    
    sut.updateCurrentTime(99.5)
    XCTAssertEqual(sut.currentLineIndex, 99)
  }
  
  // MARK: - ObservableObject Tests
  
  /// Test that lrcDocument is published
  func testLRCDocumentIsPublished() {
    let expectation = self.expectation(description: "Document published")
    
    sut.$lrcDocument
      .dropFirst() // Skip initial nil
      .sink { document in
        XCTAssertNotNil(document)
        expectation.fulfill()
      }
      .store(in: &cancellables)
    
    let lines = [LRCLine(timestamp: 10.0, text: "Test")]
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    sut.lrcDocument = document
    
    waitForExpectations(timeout: 1.0)
  }
  
  /// Test that currentTime is published
  func testCurrentTimeIsPublished() {
    let expectation = self.expectation(description: "Time published")
    
    sut.$currentTime
      .dropFirst() // Skip initial 0
      .sink { time in
        XCTAssertEqual(time, 15.0)
        expectation.fulfill()
      }
      .store(in: &cancellables)
    
    sut.updateCurrentTime(15.0)
    
    waitForExpectations(timeout: 1.0)
  }
}
