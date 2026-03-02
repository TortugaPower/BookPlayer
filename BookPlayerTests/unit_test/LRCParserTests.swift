//
//  LRCParserTests.swift
//  BookPlayerTests
//
//  Created for synchronized text viewer feature testing.
//

import Foundation
import XCTest
@testable import BookPlayer

/// Tests for LRC file parsing functionality
final class LRCParserTests: XCTestCase {

    // MARK: - Basic Parsing Tests

    /// Test parsing a valid LRC file with basic content
    func testParseValidLRCContent() throws {
        let content = """
        [00:12.00]Line one
        [00:17.50]Line two
        [00:21.00]Line three
        """

        let lines = try LRCParser.parse(content)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].text, "Line one")
        XCTAssertEqual(lines[0].time, 12.0)
        XCTAssertEqual(lines[1].text, "Line two")
        XCTAssertEqual(lines[1].time, 17.5)
        XCTAssertEqual(lines[2].text, "Line three")
        XCTAssertEqual(lines[2].time, 21.0)
    }

    /// Test parsing skips metadata and empty lines
    func testParseSkipsMetadataAndEmptyLines() throws {
        let content = """
        [ti:Sample Title]

        [00:10.00]First line

        [ar:Sample Artist]
        [00:20.00]Second line
        """

        let lines = try LRCParser.parse(content)

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "First line")
        XCTAssertEqual(lines[1].text, "Second line")
    }

    // MARK: - Timestamp Format Tests

    /// Test parsing different timestamp formats
    func testParseDifferentTimestampFormats() throws {
        let content = """
        [00:12]Line with seconds only
        [00:17.5]Line with one decimal
        [00:21,50]Line with comma decimal
        [01:02:03.50]Line with hours
        """

        let lines = try LRCParser.parse(content)

        XCTAssertEqual(lines.count, 4)
        XCTAssertEqual(lines[0].time, 12.0)
        XCTAssertEqual(lines[1].time, 17.5)
        XCTAssertEqual(lines[2].time, 21.5)
        XCTAssertEqual(lines[3].time, 3723.5)
    }

    /// Test parsing multiple timestamps on the same line
    func testParseMultipleTimestamps() throws {
        let content = """
        [00:10.00][00:30.00]Same text at different times
        [00:15.00]Different text
        """

        let lines = try LRCParser.parse(content)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].time, 10.0)
        XCTAssertEqual(lines[0].text, "Same text at different times")
        XCTAssertEqual(lines[1].time, 15.0)
        XCTAssertEqual(lines[2].time, 30.0)
        XCTAssertEqual(lines[2].text, "Same text at different times")
    }

    // MARK: - Edge Cases

    /// Test parsing empty file throws
    func testParseEmptyFile() {
        let content = ""

        XCTAssertThrowsError(try LRCParser.parse(content)) { error in
            XCTAssertTrue(error is LRCParserError)
            XCTAssertEqual(error as? LRCParserError, .noTimedLines)
        }
    }

    /// Test parsing file with only metadata throws
    func testParseOnlyMetadata() {
        let content = """
        [ti:Sample Title]
        [ar:Sample Artist]
        """

        XCTAssertThrowsError(try LRCParser.parse(content)) { error in
            XCTAssertTrue(error is LRCParserError)
            XCTAssertEqual(error as? LRCParserError, .noTimedLines)
        }
    }

    /// Test parsing with whitespace trims surrounding spaces
    func testParseWithWhitespace() throws {
        let content = """
          [00:10.00]  Line with surrounding spaces  
        [00:20.00]Normal line
        """

        let lines = try LRCParser.parse(content)

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "Line with surrounding spaces")
    }

    /// Test parsing with empty text lines skips them
    func testParseSkipsEmptyText() throws {
        let content = """
        [00:10.00]
        [00:20.00]Some text
        """

        let lines = try LRCParser.parse(content)

        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "Some text")
    }

    // MARK: - Sorting Tests

    /// Test that lines are sorted by timestamp
    func testLinesAreSortedByTimestamp() throws {
        let content = """
        [00:30.00]Third line
        [00:10.00]First line
        [00:20.00]Second line
        """

        let lines = try LRCParser.parse(content)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].text, "First line")
        XCTAssertEqual(lines[0].time, 10.0)
        XCTAssertEqual(lines[1].text, "Second line")
        XCTAssertEqual(lines[1].time, 20.0)
        XCTAssertEqual(lines[2].text, "Third line")
        XCTAssertEqual(lines[2].time, 30.0)
    }
}
