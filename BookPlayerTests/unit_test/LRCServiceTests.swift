//
//  TranscriptStoreTests.swift
//  BookPlayerTests
//
//  Created for synchronized text viewer feature testing.
//

import Foundation
import XCTest
@testable import BookPlayer

/// Tests for transcript storage behavior
final class TranscriptStoreTests: XCTestCase {

    private var sut: TranscriptStore!

    override func setUp() {
        super.setUp()
        sut = TranscriptStore()
        cleanupTestFiles()
    }

    override func tearDown() {
        cleanupTestFiles()
        sut = nil
        super.tearDown()
    }

    private func cleanupTestFiles() {
        let legacyFolder = legacyTranscriptsFolder()
        let appSupportFolder = appSupportTranscriptsFolder()

        if FileManager.default.fileExists(atPath: legacyFolder.path) {
            try? FileManager.default.removeItem(at: legacyFolder)
        }
        if FileManager.default.fileExists(atPath: appSupportFolder.path) {
            try? FileManager.default.removeItem(at: appSupportFolder)
        }
    }

    private func appSupportTranscriptsFolder() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("BookPlayer", isDirectory: true)
            .appendingPathComponent("Transcripts", isDirectory: true)
    }

    private func legacyTranscriptsFolder() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Transcripts", isDirectory: true)
    }

    private func sanitizedFileName(for relativePath: String) -> String {
        return relativePath
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }

    // MARK: - Save / Load Tests

    func testSaveAndLoadTranscript() throws {
        let relativePath = "books/test.mp3"
        let content = "[00:10.00]Line one"

        try sut.saveTranscript(content, for: relativePath)
        let loaded = try sut.loadTranscript(for: relativePath)

        XCTAssertEqual(loaded, content)
    }

    func testLoadNonExistentTranscriptReturnsNil() throws {
        let relativePath = "books/missing.mp3"
        let loaded = try sut.loadTranscript(for: relativePath)

        XCTAssertNil(loaded)
    }

    func testSaveOverwritesExistingTranscript() throws {
        let relativePath = "books/overwrite.mp3"
        let first = "[00:10.00]First line"
        let second = "[00:20.00]Second line"

        try sut.saveTranscript(first, for: relativePath)
        try sut.saveTranscript(second, for: relativePath)

        let loaded = try sut.loadTranscript(for: relativePath)
        XCTAssertEqual(loaded, second)
    }

    func testSaveSanitizesRelativePath() throws {
        let relativePath = "folder/with:bad\\name.mp3"
        let content = "[00:10.00]Line one"

        try sut.saveTranscript(content, for: relativePath)

        let expectedFileName = sanitizedFileName(for: relativePath) + ".lrc"
        let expectedURL = appSupportTranscriptsFolder().appendingPathComponent(expectedFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedURL.path))
    }

    // MARK: - Legacy Migration Tests

    func testLoadMigratesLegacyTranscript() throws {
        let relativePath = "books/legacy.mp3"
        let content = "[00:10.00]Legacy line"

        let legacyFolder = legacyTranscriptsFolder()
        try FileManager.default.createDirectory(at: legacyFolder, withIntermediateDirectories: true, attributes: nil)
        let legacyURL = legacyFolder.appendingPathComponent(sanitizedFileName(for: relativePath) + ".lrc")
        try content.write(to: legacyURL, atomically: true, encoding: .utf8)

        let loaded = try sut.loadTranscript(for: relativePath)

        XCTAssertEqual(loaded, content)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))

        let migratedURL = appSupportTranscriptsFolder().appendingPathComponent(sanitizedFileName(for: relativePath) + ".lrc")
        XCTAssertTrue(FileManager.default.fileExists(atPath: migratedURL.path))
    }

    func testLoadRemovesEmptyLegacyFolderAfterMigration() throws {
        let relativePath = "books/legacy_cleanup.mp3"
        let content = "[00:10.00]Legacy line"

        let legacyFolder = legacyTranscriptsFolder()
        try FileManager.default.createDirectory(at: legacyFolder, withIntermediateDirectories: true, attributes: nil)
        let legacyURL = legacyFolder.appendingPathComponent(sanitizedFileName(for: relativePath) + ".lrc")
        try content.write(to: legacyURL, atomically: true, encoding: .utf8)

        _ = try sut.loadTranscript(for: relativePath)

        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFolder.path))
    }
}
