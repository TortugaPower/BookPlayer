//
//  AudioMetadataServiceTests.swift
//  BookPlayerTests
//
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AVFoundation
@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

final class AudioMetadataServiceTests: XCTestCase {
  var sut: AudioMetadataService!

  override func setUp() {
    super.setUp()
    sut = AudioMetadataService()
  }

  private func fixtureURL(_ name: String, _ ext: String) throws -> URL {
    let url = Bundle(for: Self.self).url(forResource: name, withExtension: ext)
    return try XCTUnwrap(url, "Missing fixture \(name).\(ext)")
  }

  // MARK: - extractMetadata (native-first, with manual fallbacks)

  func testExtractMetadata_wellFormedM4B_returnsChaptersViaNative() async throws {
    let url = try fixtureURL("m4b_WELLFORMED", "m4b")
    let metadata = await sut.extractMetadata(from: url)
    XCTAssertEqual(metadata?.chapters?.count, 4)
    XCTAssertEqual(metadata?.chapters?.first?.title, "Chapter One – Intro")
  }

  func testExtractMetadata_mp3WithCTOC_returnsChaptersViaNative() async throws {
    let url = try fixtureURL("mp3_WITH_toc", "mp3")
    let metadata = await sut.extractMetadata(from: url)
    XCTAssertEqual(metadata?.chapters?.count, 4)
  }

  func testExtractMetadata_malformedM4B_recoversViaQuickTimeFallback() async throws {
    // AVFoundation reports no chapters for this file; extractMetadata must fall through to the
    // manual QuickTime text-track parser.
    let url = try fixtureURL("m4b_MALFORMED", "m4b")
    let metadata = await sut.extractMetadata(from: url)
    XCTAssertEqual(metadata?.chapters?.count, 4)
  }

  func testExtractMetadata_mp3WithoutCTOC_recoversViaID3Fallback() async throws {
    // No CTOC frame, so AVFoundation exposes nothing; the ID3 CHAP parser recovers them.
    let url = try fixtureURL("mp3_NO_toc_v23", "mp3")
    let metadata = await sut.extractMetadata(from: url)
    XCTAssertEqual(metadata?.chapters?.count, 4)
  }

  func testExtractMetadata_noChapters_returnsNilChapters() async throws {
    let url = try fixtureURL("mp3_NO_chapters", "mp3")
    let metadata = await sut.extractMetadata(from: url)
    XCTAssertNil(metadata?.chapters)
  }

  // MARK: - extractManualChapters (bypasses AVFoundation native)

  func testExtractManualChapters_malformedM4B() async throws {
    let url = try fixtureURL("m4b_MALFORMED", "m4b")
    let chapters = await sut.extractManualChapters(from: url)
    XCTAssertEqual(chapters?.count, 4)
  }

  func testExtractManualChapters_mp3NoCTOC_v23() async throws {
    let url = try fixtureURL("mp3_NO_toc_v23", "mp3")
    let chapters = await sut.extractManualChapters(from: url)
    XCTAssertEqual(chapters?.count, 4)
  }

  func testExtractManualChapters_mp3NoCTOC_v24() async throws {
    let url = try fixtureURL("mp3_NO_toc_v24", "mp3")
    let chapters = await sut.extractManualChapters(from: url)
    XCTAssertEqual(chapters?.count, 4)
  }

  func testExtractManualChapters_wellFormedM4B_isChronologicalAndTitled() async throws {
    let url = try fixtureURL("m4b_WELLFORMED", "m4b")
    let parsed = await sut.extractManualChapters(from: url)
    let chapters = try XCTUnwrap(parsed)
    XCTAssertEqual(chapters.count, 4)
    XCTAssertEqual(chapters.map(\.start), chapters.map(\.start).sorted())
    XCTAssertFalse(chapters.contains { $0.title.isEmpty })
  }

  func testExtractManualChapters_noChapters_returnsNil() async throws {
    let url = try fixtureURL("mp3_NO_chapters", "mp3")
    let chapters = await sut.extractManualChapters(from: url)
    XCTAssertNil(chapters)
  }
}
