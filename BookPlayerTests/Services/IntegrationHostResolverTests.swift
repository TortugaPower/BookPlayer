//
//  IntegrationHostResolverTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayerKit

/// Pins the cross-platform stable-host resolution contract (the Android app ships the same
/// rules in its `ServerResolutionTest`): GUID match is case-insensitive, the URL fallback uses
/// the canonical dedup key, and an unknown host resolves to NOTHING — never to whichever
/// connection happens to exist.
final class IntegrationHostResolverTests: XCTestCase {
  private func connection(serverId: String?, url: String, id: String = UUID().uuidString) -> JellyfinConnectionData {
    JellyfinConnectionData(
      id: id,
      serverId: serverId,
      url: URL(string: url)!,
      serverName: "srv",
      userID: "user-1",
      userName: "name",
      accessToken: "token"
    )
  }

  func testMatchesByServerIdCaseInsensitively() {
    // Jellyfin reports lowercase hex, ABS uppercase UUIDs — casing must never break the match.
    let connections = [connection(serverId: "ABC-DEF-123", url: "https://jf.example.com")]
    let hit = IntegrationHostResolver.connection(for: "abc-def-123", in: connections)
    XCTAssertEqual(hit?.serverId, "ABC-DEF-123")
  }

  func testFallsBackToCanonicalUrlKeyForGuidlessConnections() {
    // The other device imported against this server before it reported a GUID: hostId is the
    // canonical key. This device saved the same URL with default port + trailing slash.
    let connections = [connection(serverId: nil, url: "https://jf.example.com:443/")]
    let hit = IntegrationHostResolver.connection(
      for: URL(string: "https://jf.example.com")!.canonicalDedupKey,
      in: connections
    )
    XCTAssertNotNil(hit)
  }

  func testUnknownHostResolvesToNothing() {
    // The old `?? connections.first` guess streamed the wrong file / pushed progress to the
    // wrong server when provider ids collide across instances.
    let connections = [connection(serverId: "real-guid", url: "https://jf.example.com")]
    XCTAssertNil(IntegrationHostResolver.connection(for: "other-guid", in: connections))
    XCTAssertNil(IntegrationHostResolver.connection(for: nil, in: connections))
    XCTAssertNil(IntegrationHostResolver.connection(for: "", in: connections))
  }

  func testStableHostIdPrefersGuidOverCanonicalKey() {
    let withGuid = connection(serverId: "guid-1", url: "https://jf.example.com/")
    XCTAssertEqual(withGuid.stableHostId, "guid-1")

    let withoutGuid = connection(serverId: nil, url: "https://jf.example.com/")
    XCTAssertEqual(withoutGuid.stableHostId, withoutGuid.url.canonicalDedupKey)
  }
}
