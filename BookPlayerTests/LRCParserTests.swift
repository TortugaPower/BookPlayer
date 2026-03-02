//
//  LRCParserTests.swift
//  BookPlayerTests
//
//  Created for synchronized text viewer feature testing.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import XCTest
@testable import BookPlayer
@testable import BookPlayerKit

/// Tests for LRC file parsing functionality
class LRCParserTests: XCTestCase {
  
  // MARK: - Basic Parsing Tests
  
  /// Test parsing a valid LRC file with basic content
  func testParseValidLRCContent() throws {
    let content = """
    [00:12.00]Line one
    [00:17.50]Line two
    [00:21.00]Line three
    """
    
    let document = try LRCParser.parse(content: content)
    
    XCTAssertEqual(document.lines.count, 3)
    XCTAssertEqual(document.lines[0].text, "Line one")
    XCTAssertEqual(document.lines[0].timestamp, 12.0)
    XCTAssertEqual(document.lines[1].text, "Line two")
    XCTAssertEqual(document.lines[1].timestamp, 17.5)
    XCTAssertEqual(document.lines[2].text, "Line three")
    XCTAssertEqual(document.lines[2].timestamp, 21.0)
  }
  
  /// Test parsing LRC with metadata tags
  func testParseMetadata() throws {
    let content = """
    [ti:Song Title]
    [ar:Artist Name]
    [al:Album Name]
    [au:Author Name]
    [by:Creator Name]
    [00:12.00]First line
    [00:17.50]Second line
    """
    
    let document = try LRCParser.parse(content: content)
    
    XCTAssertEqual(document.metadata.title, "Song Title")
    XCTAssertEqual(document.metadata.artist, "Artist Name")
    XCTAssertEqual(document.metadata.album, "Album Name")
    XCTAssertEqual(document.metadata.author, "Author Name")
    XCTAssertEqual(document.metadata.creator, "Creator Name")
    XCTAssertEqual(document.lines.count, 2)
  }
  
  /// Test parsing with offset metadata
  func testParseWithOffset() throws {
    let content = """
    [offset:500]
    [00:10.00]Line one
    [00:20.00]Line two
    """
    
    let document = try LRCParser.parse(content: content)
    
    // Offset is 500ms = 0.5 seconds, should be added to all timestamps
    XCTAssertEqual(document.metadata.offset, 0.5)
    XCTAssertEqual(document.lines[0].timestamp, 10.5)
    XCTAssertEqual(document.lines[1].timestamp, 20.5)
  }
  
  /// Test parsing with negative offset
  func testParseWithNegativeOffset() throws {
    let content = """
    [offset:-1000]
    [00:10.00]Line one
    [00:05.00]Line two
    """
    
    let document = try LRCParser.parse(content: content)
    
    // Negative offset should reduce timestamps, but not go below 0
    XCTAssertEqual(document.metadata.offset, -1.0)
  }
  
  // MARK: - Timestamp Format Tests
  
  /// Test parsing different timestamp formats
  func testParseDifferentTimestampFormats() throws {
    let content = """
    [00:12]Line with seconds only
    [00:17.5]Line with one decimal
    [00:21.50]Line with two decimals
    [00:25.500]Line with three decimals
    """
    
    let document = try LRCParser.parse(content: content)
    
    XCTAssertEqual(document.lines.count, 4)
    XCTAssertEqual(document.lines[0].timestamp, 12.0)
  }
  
  /// Test parsing multiple timestamps on same line
  func testParseMultipleTimestamps() throws {
    let content = """
    [00:10.00][00:30.00]Same text at different times
    [00:15.00]Different text
    """
    
    let document = try LRCParser.parse(content: content)
    
    // Should create separate lines for each timestamp
    XCTAssertEqual(document.lines.count, 3)
    XCTAssertEqual(document.lines[0].timestamp, 10.0)
    XCTAssertEqual(document.lines[0].text, "Same text at different times")
    XCTAssertEqual(document.lines[1].timestamp, 15.0)
    XCTAssertEqual(document.lines[2].timestamp, 30.0)
    XCTAssertEqual(document.lines[2].text, "Same text at different times")
  }
  
  // MARK: - Edge Cases
  
  /// Test parsing empty file
  func testParseEmptyFile() {
    let content = ""
    
    XCTAssertThrowsError(try LRCParser.parse(content: content)) { error in
      XCTAssertTrue(error is LRCParserError)
      XCTAssertEqual(error as? LRCParserError, .emptyFile)
    }
  }
  
  /// Test parsing file with only metadata
  func testParseOnlyMetadata() {
    let content = """
    [ti:Song Title]
    [ar:Artist Name]
    """
    
    XCTAssertThrowsError(try LRCParser.parse(content: content)) { error in
      XCTAssertTrue(error is LRCParserError)
      XCTAssertEqual(error as? LRCParserError, .invalidFileFormat)
    }
  }
  
  /// Test parsing with empty lines
  func testParseWithEmptyLines() throws {
    let content = """
    [00:10.00]Line one
    
    [00:20.00]Line two
    
    
    [00:30.00]Line three
    """
    
    let document = try LRCParser.parse(content: content)
    
    // Empty lines should be skipped
    XCTAssertEqual(document.lines.count, 3)
  }
  
  /// Test parsing with whitespace
  func testParseWithWhitespace() throws {
    let content = """
      [00:10.00]  Line with leading and trailing spaces  
    [00:20.00]Normal line
    """
    
    let document = try LRCParser.parse(content: content)
    
    XCTAssertEqual(document.lines.count, 2)
    // Text should preserve internal spaces but trim leading/trailing
    XCTAssertEqual(document.lines[0].text, "Line with leading and trailing spaces")
  }
  
  /// Test parsing with empty text
  func testParseWithEmptyText() throws {
    let content = """
    [00:10.00]
    [00:20.00]Some text
    """
    
    let document = try LRCParser.parse(content: content)
    
    XCTAssertEqual(document.lines.count, 2)
    XCTAssertEqual(document.lines[0].text, "")
    XCTAssertEqual(document.lines[1].text, "Some text")
  }
  
  // MARK: - Sorting Tests
  
  /// Test that lines are sorted by timestamp
  func testLinesAreSortedByTimestamp() throws {
    let content = """
    [00:30.00]Third line
    [00:10.00]First line
    [00:20.00]Second line
    """
    
    let document = try LRCParser.parse(content: content)
    
    XCTAssertEqual(document.lines.count, 3)
    XCTAssertEqual(document.lines[0].text, "First line")
    XCTAssertEqual(document.lines[0].timestamp, 10.0)
    XCTAssertEqual(document.lines[1].text, "Second line")
    XCTAssertEqual(document.lines[1].timestamp, 20.0)
    XCTAssertEqual(document.lines[2].text, "Third line")
    XCTAssertEqual(document.lines[2].timestamp, 30.0)
  }
  
  // MARK: - LRCDocument Tests
  
  /// Test getLineIndex functionality
  func testGetLineIndex() {
    let lines = [
      LRCLine(timestamp: 10.0, text: "First"),
      LRCLine(timestamp: 20.0, text: "Second"),
      LRCLine(timestamp: 30.0, text: "Third")
    ]
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    
    // Before first line
    XCTAssertNil(document.getLineIndex(for: 5.0))
    
    // At first line
    XCTAssertEqual(document.getLineIndex(for: 10.0), 0)
    
    // Between first and second
    XCTAssertEqual(document.getLineIndex(for: 15.0), 0)
    
    // At second line
    XCTAssertEqual(document.getLineIndex(for: 20.0), 1)
    
    // Between second and third
    XCTAssertEqual(document.getLineIndex(for: 25.0), 1)
    
    // After last line
    XCTAssertEqual(document.getLineIndex(for: 40.0), 2)
  }
  
  /// Test getLine functionality
  func testGetLine() {
    let lines = [
      LRCLine(timestamp: 10.0, text: "First"),
      LRCLine(timestamp: 20.0, text: "Second"),
      LRCLine(timestamp: 30.0, text: "Third")
    ]
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    
    XCTAssertNil(document.getLine(for: 5.0))
    XCTAssertEqual(document.getLine(for: 10.0)?.text, "First")
    XCTAssertEqual(document.getLine(for: 15.0)?.text, "First")
    XCTAssertEqual(document.getLine(for: 20.0)?.text, "Second")
    XCTAssertEqual(document.getLine(for: 35.0)?.text, "Third")
  }
  
  /// Test empty document
  func testGetLineIndexEmptyDocument() {
    let document = LRCDocument(metadata: LRCMetadata(), lines: [])
    
    XCTAssertNil(document.getLineIndex(for: 10.0))
    XCTAssertNil(document.getLine(for: 10.0))
  }
  
  // MARK: - File Parsing Tests
  
  /// Test parsing from actual file URL
  func testParseFromFile() throws {
    // Create a temporary LRC file
    let tempDirectory = FileManager.default.temporaryDirectory
    let fileURL = tempDirectory.appendingPathComponent("test.lrc")
    
    let content = """
    [ti:Test Song]
    [ar:Test Artist]
    [00:10.00]First line
    [00:20.00]Second line
    """
    
    try content.write(to: fileURL, atomically: true, encoding: .utf8)
    
    defer {
      try? FileManager.default.removeItem(at: fileURL)
    }
    
    let document = try LRCParser.parse(from: fileURL)
    
    XCTAssertEqual(document.metadata.title, "Test Song")
    XCTAssertEqual(document.metadata.artist, "Test Artist")
    XCTAssertEqual(document.lines.count, 2)
  }
  
  /// Test parsing from non-existent file
  func testParseFromNonExistentFile() {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent.lrc")
    
    XCTAssertThrowsError(try LRCParser.parse(from: fileURL)) { error in
      XCTAssertTrue(error is LRCParserError)
      XCTAssertEqual(error as? LRCParserError, .readError)
    }
  }
  
  // MARK: - Alternative Metadata Tag Tests
  
  /// Test parsing with alternative metadata tag formats
  func testParseAlternativeMetadataTags() throws {
    let content = """
    [title:Full Title Tag]
    [artist:Full Artist Tag]
    [album:Full Album Tag]
    [author:Full Author Tag]
    [creator:Full Creator Tag]
    [00:10.00]Line one
    """
    
    let document = try LRCParser.parse(content: content)
    
    XCTAssertEqual(document.metadata.title, "Full Title Tag")
    XCTAssertEqual(document.metadata.artist, "Full Artist Tag")
    XCTAssertEqual(document.metadata.album, "Full Album Tag")
    XCTAssertEqual(document.metadata.author, "Full Author Tag")
    XCTAssertEqual(document.metadata.creator, "Full Creator Tag")
  }
}
