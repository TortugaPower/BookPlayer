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
}
