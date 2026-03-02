//
//  TranscriptImporterTests.swift
//  BookPlayerTests
//
//  Created for synchronized text viewer feature testing.
//

import Foundation
import XCTest
@testable import BookPlayer

/// Tests for transcript import flow (parse + store)
final class TranscriptImporterTests: XCTestCase {

    private var store: TranscriptStore!

    override func setUp() {
        super.setUp()
        store = TranscriptStore()
        cleanupTestFiles()
    }

    override func tearDown() {
        cleanupTestFiles()
        store = nil
        super.tearDown()
    }

    private func cleanupTestFiles() {
        let appSupportFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let transcriptsFolder = appSupportFolder
            .appendingPathComponent("BookPlayer", isDirectory: true)
            .appendingPathComponent("Transcripts", isDirectory: true)

        if FileManager.default.fileExists(atPath: transcriptsFolder.path) {
            try? FileManager.default.removeItem(at: transcriptsFolder)
        }
    }

    private func importTranscript(contents: String, relativePath: String) throws {
        _ = try LRCParser.parse(contents)
        try store.saveTranscript(contents, for: relativePath)
    }

    // MARK: - Error Handling Tests

    func testParserErrorDescriptions() {
        let error = LRCParserError.noTimedLines
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    // MARK: - Integration Tests

    func testImportedFileCanBeLoaded() throws {
        let relativePath = "books/integration_test.mp3"
        let content = """
        [00:10.00]First line
        [00:20.00]Second line
        """

        try importTranscript(contents: content, relativePath: relativePath)

        let loaded = try store.loadTranscript(for: relativePath)
        XCTAssertNotNil(loaded)

        let lines = try LRCParser.parse(loaded ?? "")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "First line")
    }

    func testImportInvalidFileFails() {
        let relativePath = "books/invalid_test.mp3"
        let content = ""

        XCTAssertThrowsError(try importTranscript(contents: content, relativePath: relativePath)) { error in
            XCTAssertTrue(error is LRCParserError)
            XCTAssertEqual(error as? LRCParserError, .noTimedLines)
        }

        let loaded = try? store.loadTranscript(for: relativePath)
        XCTAssertNil(loaded)
    }

    func testImportMultipleFiles() throws {
        let items = [
            ("books/book1.mp3", "[00:10.00]Line one"),
            ("books/book2.mp3", "[00:20.00]Line two"),
            ("books/book3.mp3", "[00:30.00]Line three")
        ]

        for (path, content) in items {
            try importTranscript(contents: content, relativePath: path)
        }

        for (path, _) in items {
            let loaded = try store.loadTranscript(for: path)
            XCTAssertNotNil(loaded)
        }
    }

    func testOverwriteExistingTranscript() throws {
        let relativePath = "books/overwrite_test.mp3"

        try importTranscript(contents: "[00:10.00]First line", relativePath: relativePath)
        try importTranscript(contents: "[00:20.00]Second line", relativePath: relativePath)

        let loaded = try store.loadTranscript(for: relativePath)
        XCTAssertEqual(loaded, "[00:20.00]Second line")
    }

    func testImportFileWithLongContent() throws {
        let relativePath = "books/long_content.mp3"
        var content = ""
        for i in 0..<100 {
            let minutes = i / 60
            let seconds = i % 60
            content += String(format: "[%02d:%02d.00]Line %d\n", minutes, seconds, i)
        }

        try importTranscript(contents: content, relativePath: relativePath)

        let loaded = try store.loadTranscript(for: relativePath)
        XCTAssertNotNil(loaded)

        let lines = try LRCParser.parse(loaded ?? "")
        XCTAssertEqual(lines.count, 100)
    }
}
