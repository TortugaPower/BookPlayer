//
//  PlayableChapterTests.swift
//  BookPlayerTests
//
//  Created by BookPlayer on 20/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import XCTest

@testable import BookPlayerKit

class PlayableChapterTests: XCTestCase {
  private func makeChapter(relativePath: String) -> PlayableChapter {
    PlayableChapter(
      title: "test",
      author: "test",
      start: 0,
      duration: 1,
      relativePath: relativePath,
      remoteURL: nil,
      externalURL: nil,
      index: 0
    )
  }

  func testIsVideoForVideoExtensions() {
    // Containers AVFoundation plays and iOS reliably classifies as movies.
    // (`.mkv` is a movie UTType on macOS but NOT on iOS — don't assert it here.)
    for path in ["movie.mp4", "movie.mov", "movie.m4v"] {
      XCTAssertTrue(makeChapter(relativePath: path).isVideo, "\(path) should be detected as video")
    }
  }

  func testIsVideoForAudioExtensions() {
    for path in ["book.m4b", "book.mp3", "book.aac", "book.wav"] {
      XCTAssertFalse(makeChapter(relativePath: path).isVideo, "\(path) should not be detected as video")
    }
  }

  func testIsVideoIsCaseInsensitive() {
    XCTAssertTrue(makeChapter(relativePath: "movie.MP4").isVideo)
    XCTAssertTrue(makeChapter(relativePath: "movie.MOV").isVideo)
  }

  func testIsVideoForNestedRelativePath() {
    XCTAssertTrue(makeChapter(relativePath: "folder/sub/movie.mp4").isVideo)
    XCTAssertFalse(makeChapter(relativePath: "folder/sub/book.m4b").isVideo)
  }

  /// Only the last path component's extension matters — a video-looking folder name
  /// must not produce a false positive (or negative).
  func testIsVideoConsidersOnlyTheLastComponent() {
    XCTAssertTrue(makeChapter(relativePath: "my.folder/movie.mp4").isVideo)
    XCTAssertFalse(makeChapter(relativePath: "my.mp4.folder/book.m4b").isVideo)
  }

  func testIsVideoForMissingOrEmptyExtension() {
    XCTAssertFalse(makeChapter(relativePath: "no_extension").isVideo)
    XCTAssertFalse(makeChapter(relativePath: "folder/no_extension").isVideo)
    XCTAssertFalse(makeChapter(relativePath: "").isVideo)
  }

  /// Regression guard for the CodingKeys exclusion: encoded chapters travel through the
  /// WatchConnectivity application context, which the system persists to disk on both
  /// devices — the media server's live Authorization token must never be in that payload.
  func testCodableExcludesExternalUrlAndHeaders() throws {
    let chapter = PlayableChapter(
      title: "test",
      author: "test",
      start: 0,
      duration: 1,
      relativePath: "book.m4b",
      remoteURL: URL(string: "https://cloud.example.com/book.m4b"),
      externalURL: URL(string: "https://jellyfin.local/Items/abc/Download?api_key=SECRET-TOKEN"),
      index: 0,
      externalHeaders: ["Authorization": "Bearer SECRET-TOKEN"]
    )

    let data = try JSONEncoder().encode(chapter)
    let json = String(decoding: data, as: UTF8.self)

    XCTAssertFalse(json.contains("SECRET-TOKEN"), "the media-server token leaked into the encoded payload")
    XCTAssertFalse(json.contains("Authorization"), "externalHeaders leaked into the encoded payload")
    XCTAssertFalse(json.contains("externalUrl"), "externalUrl leaked into the encoded payload")
    XCTAssertFalse(json.contains("jellyfin.local"), "the external URL leaked into the encoded payload")
    // The cloud remoteURL is NOT sensitive and must still round-trip
    XCTAssertTrue(json.contains("cloud.example.com"))

    let decoded = try JSONDecoder().decode(PlayableChapter.self, from: data)
    XCTAssertNil(decoded.externalUrl)
    XCTAssertTrue(decoded.externalHeaders.isEmpty)
  }
}
