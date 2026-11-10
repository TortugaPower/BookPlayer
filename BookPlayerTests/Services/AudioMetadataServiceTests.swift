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

  // MARK: - Duration of VBR files
  //
  // Both fixtures are 30s of silence then 30s of noise, so the bitrate of the first frames
  // says little about the rest. Without precise timing AVFoundation estimates 67.6s for
  // the MP3 and 88.8s for the Opus file. Generated with:
  //   ffmpeg -f lavfi -i "anullsrc=r=44100:cl=mono:d=30" -f lavfi -i "anoisesrc=r=44100:d=30:a=0.5:seed=1" \
  //     -filter_complex "[0][1]concat=n=2:v=0:a=1" -map_metadata -1 -fflags +bitexact \
  //     -c:a libmp3lame -q:a 9 -write_xing 0 mp3_VBR_NO_xing.mp3
  //   (same with r=48000 and -c:a libopus -b:a 32k -vbr on opus_VBR.opus)

  func testExtractMetadata_vbrMP3WithoutXingHeader_returnsPreciseDuration() async throws {
    let url = try fixtureURL("mp3_VBR_NO_xing", "mp3")
    let extracted = await sut.extractMetadata(from: url)
    let metadata = try XCTUnwrap(extracted)
    XCTAssertEqual(metadata.duration, 60, accuracy: 0.5)
  }

  func testExtractMetadata_vbrOpus_returnsPreciseDuration() async throws {
    let url = try fixtureURL("opus_VBR", "opus")
    let extracted = await sut.extractMetadata(from: url)
    let metadata = try XCTUnwrap(extracted)
    XCTAssertEqual(metadata.duration, 60, accuracy: 0.5)
  }

  // MARK: - Download verification against estimated or precise synced durations

  func testVerifiedDuration_acceptsPreciseSyncedDuration() async throws {
    let url = try fixtureURL("opus_VBR", "opus")
    let duration = try await SyncService.verifiedDuration(of: url, expectedDuration: 60)
    XCTAssertFalse(SyncService.isDurationShort(duration, expected: 60))
  }

  func testVerifiedDuration_acceptsEstimatedSyncedDuration() async throws {
    // A book imported before precise timing stored AVFoundation's estimate
    let url = try fixtureURL("opus_VBR", "opus")
    let estimate = CMTimeGetSeconds(try await AVURLAsset(url: url).load(.duration))
    let duration = try await SyncService.verifiedDuration(of: url, expectedDuration: estimate)
    XCTAssertFalse(SyncService.isDurationShort(duration, expected: estimate))
  }

  func testVerifiedDuration_rejectsTruncatedFile() async throws {
    let url = try fixtureURL("opus_VBR", "opus")
    let duration = try await SyncService.verifiedDuration(of: url, expectedDuration: 200)
    XCTAssertTrue(SyncService.isDurationShort(duration, expected: 200))
  }
}
