//
//  ArtworkServiceLegacyCacheTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayerKit

/// Artwork cached before 6.0.0 sits under Kingfisher 7's file names (the key's MD5), which
/// Kingfisher 8 never reads. These run against the app's real artwork cache, with keys of their own.
final class ArtworkServiceLegacyCacheTests: XCTestCase {
  private var keys = [String]()

  override func tearDown() async throws {
    for key in keys {
      await ArtworkService.removeCache(for: key)
      try? FileManager.default.removeItem(at: legacyURL(for: key))
    }
    keys = []
    try await super.tearDown()
  }

  func testLegacyFileNameIsKingfisher7sHexMD5() {
    XCTAssertEqual(
      ArtworkService.legacyCacheFileName(forKey: "The quick brown fox jumps over the lazy dog"),
      "9e107d9d372bb6826bd81d3542a419d6"
    )
    XCTAssertEqual(ArtworkService.legacyCacheFileName(forKey: ""), "d41d8cd98f00b204e9800998ecf8427e")
  }

  /// The reported case: a cover set by hand in 5.x, and the embedded one 6.0.0 cached since
  func testOldCoverReplacesWhat600Cached() async throws {
    let key = makeKey("Set by hand.m4b")
    let cover = try image(.red)
    let embedded = try image(.blue)
    await ArtworkService.storeInCache(embedded, for: key)
    try cover.write(to: legacyURL(for: key))

    let result = ArtworkService.restoreLegacyCacheFiles(for: [key])

    XCTAssertEqual(result.restored, [key])
    XCTAssertTrue(result.complete)
    XCTAssertEqual(try Data(contentsOf: ArtworkService.getCachedImageURL(for: key)), cover)
    XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL(for: key).path))
  }

  /// Nothing cached under the new name yet: the restored file must be seen as cached, not
  /// missed by the cache's list of file names (which would extract the embedded cover again)
  func testOldCoverWithNothingCachedSinceIsFoundByTheCache() async throws {
    let key = makeKey("Never shown in 6.0.0.m4b")
    let cover = try image(.green)
    try cover.write(to: legacyURL(for: key))

    XCTAssertEqual(ArtworkService.restoreLegacyCacheFiles(for: [key]).restored, [key])

    XCTAssertTrue(ArtworkService.isCached(relativePath: key))
    let retrieved = await withCheckedContinuation { continuation in
      ArtworkService.retrieveImageFromCache(for: key) { continuation.resume(returning: try? $0.get()) }
    }
    XCTAssertNotNil(retrieved, "Kingfisher reads the restored file as the item's artwork")
    XCTAssertEqual(try Data(contentsOf: ArtworkService.getCachedImageURL(for: key)), cover)
  }

  func testItemWithoutAnOldFileKeepsItsArtwork() async throws {
    let key = makeKey("Imported in 6.0.0.m4b")
    let artwork = try image(.yellow)
    await ArtworkService.storeInCache(artwork, for: key)

    let result = ArtworkService.restoreLegacyCacheFiles(for: [key])

    XCTAssertEqual(result.restored, [])
    XCTAssertTrue(result.complete)
    XCTAssertEqual(try Data(contentsOf: ArtworkService.getCachedImageURL(for: key)), artwork)
  }

  func testRunningAgainChangesNothing() async throws {
    let key = makeKey("Folder/Chapter 1.mp3")
    let cover = try image(.purple)
    try cover.write(to: legacyURL(for: key))
    XCTAssertEqual(ArtworkService.restoreLegacyCacheFiles(for: [key, key]).restored, [key])

    let newer = try image(.orange)
    await ArtworkService.storeInCache(newer, for: key)

    XCTAssertEqual(ArtworkService.restoreLegacyCacheFiles(for: [key]).restored, [])
    XCTAssertEqual(try Data(contentsOf: ArtworkService.getCachedImageURL(for: key)), newer)
  }

  // MARK: - Helpers

  private func makeKey(_ name: String) -> String {
    let key = "ArtworkServiceLegacyCacheTests-\(UUID().uuidString)/\(name)"
    keys.append(key)
    return key
  }

  private func legacyURL(for key: String) -> URL {
    ArtworkService.cacheDirectoryURL.appendingPathComponent(ArtworkService.legacyCacheFileName(forKey: key))
  }

  private func image(_ color: UIColor) throws -> Data {
    let rendered = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
      color.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    }
    return try XCTUnwrap(rendered.pngData())
  }
}
