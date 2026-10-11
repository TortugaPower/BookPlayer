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
    // Casing must never break the match.
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

  /// Android 1.1.3–1.2.x stored ABS's `serverSettings.id`, the constant "server-settings" on
  /// every server, as each ABS book's hostId. It names no server, so it resolves to nothing —
  /// even with exactly one ABS server saved, which would otherwise be a tempting guess.
  func testTheLegacyServerSettingsHostIdResolvesToNothing() {
    let connections = [
      AudiobookShelfConnectionData(
        id: "a",
        url: URL(string: "https://abs.example.com")!,
        serverName: "Home",
        userID: "u1",
        userName: "name",
        apiToken: "token"
      )
    ]

    XCTAssertNil(IntegrationHostResolver.connection(for: "server-settings", in: connections))
    XCTAssertNotNil(IntegrationHostResolver.connection(for: "https://abs.example.com", in: connections))
  }

  /// An ABS connection's identity is its address: it has no instance id.
  func testAnAudiobookShelfConnectionIsIdentifiedByItsAddress() {
    let connection = AudiobookShelfConnectionData(
      id: "a",
      url: URL(string: "HTTPS://ABS.Example.com:443/sub/")!,
      serverName: "Home",
      userID: "u1",
      userName: "name",
      apiToken: "token"
    )

    XCTAssertEqual(connection.stableHostId, "https://abs.example.com/sub")
  }

  // MARK: - Canonical key parity

  /// What Android phones store for the same addresses, so an ABS book's hostId (this key of
  /// the address it was imported from) finds its server on the other platform. Each expected
  /// key was produced by Android's `canonicalServerKey` running on AOSP's own `java.net.URI`
  /// (android-36), not the desktop JVM's: Android allows `_` in hostnames, the JVM doesn't, and
  /// Android's own JVM unit test can't see the difference.
  func testCanonicalKeyMatchesAndroidForEveryAddress() {
    let cases: [(input: String, key: String)] = [
      // The table Android's CanonicalServerKeyParityTest shares.
      ("https://abs.example.com", "https://abs.example.com"),
      ("https://abs.example.com/", "https://abs.example.com"),
      ("HTTPS://ABS.Example.COM:443/", "https://abs.example.com"),
      ("http://10.0.2.2:13378", "http://10.0.2.2:13378"),
      ("http://192.168.1.10:80/", "http://192.168.1.10"),
      ("https://media.example.com/audiobookshelf/", "https://media.example.com/audiobookshelf"),
      ("https://nas.tailnet-1234.ts.net:5006", "https://nas.tailnet-1234.ts.net:5006"),
      ("http://nas.local:8096//", "http://nas.local:8096"),
      ("https://abs.example.com/?a=b#frag", "https://abs.example.com"),
      ("https://user:pw@abs.example.com", "https://abs.example.com"),
      ("http://[::1]:8080", "http://[::1]:8080"),
      ("https://abs.example.com:443/sub/path/", "https://abs.example.com/sub/path"),
      ("http://ABS.local:13378/Audiobookshelf", "http://abs.local:13378/Audiobookshelf"),
      // The path is percent-decoded.
      ("https://example.com/my%20abs", "https://example.com/my abs"),
      ("https://abs.example.com/a%2Fb/", "https://abs.example.com/a/b"),
      ("https://abs.example.com/%C3%A9t%C3%A9/", "https://abs.example.com/été"),
      // Underscores: a host on Android, except at the start of a label.
      ("http://my_nas:80", "http://my_nas"),
      ("http://My_NAS:13378/Audiobookshelf/", "http://my_nas:13378/Audiobookshelf"),
      ("https://abs_home.duckdns.org:443/", "https://abs_home.duckdns.org"),
      ("http://user:pw@my_nas:13378", "http://my_nas:13378"),
      ("http://nas_:13378/", "http://nas_:13378"),
      ("http://nas_.local:80", "http://nas_.local"),
      ("http://_nas:13378", "http://_nas:13378"),
      // Other hosts it rejects, which keep the whole address: a label ending in a hyphen, an
      // empty label, an out-of-range IPv4 octet, a numeric last label.
      ("http://nas-.local:80", "http://nas-.local:80"),
      ("http://a..b:80", "http://a..b:80"),
      ("http://192.168.1.300:80/", "http://192.168.1.300:80"),
      ("http://1.2.3:80", "http://1.2.3:80"),
      ("http://nas.1abc:80", "http://nas.1abc:80"),
      // …and ones it accepts.
      ("http://nas.local.:80/", "http://nas.local."),
      ("http://localhost:13378", "http://localhost:13378"),
      ("http://LOCALHOST:80", "http://localhost"),
      ("http://123:80/x", "http://123/x"),
      ("http://[FE80::1]:80/", "http://[fe80::1]"),
      ("https://xn--caf-dma.example.com:443/ABS", "https://xn--caf-dma.example.com/ABS"),
      // An empty port, and dot segments, which neither side resolves.
      ("http://host:/x", "http://host/x"),
      ("https://Abs.Example.com:8443/ABS/../x", "https://abs.example.com:8443/ABS/../x"),
      ("http://nas.local:80/abs/./x/", "http://nas.local/abs/./x"),
    ]

    // Accepted divergence, pinned so it can't change unnoticed: Foundation stores an
    // internationalized host as punycode, while Android keeps one typed in Unicode as typed
    // and, its URI rejecting the host, keys the whole string: `https://café.example.com:443/abs`.
    XCTAssertEqual(
      URL(string: "https://café.example.com:443/abs")?.canonicalDedupKey,
      "https://xn--caf-dma.example.com/abs"
    )

    let mismatches = cases.compactMap { input, key -> String? in
      let actual = URL(string: input)!.canonicalDedupKey
      return actual == key ? nil : "\(input) -> \(actual) (Android: \(key))"
    }

    XCTAssertEqual(mismatches, [])
  }

  func testStableHostIdPrefersGuidOverCanonicalKey() {
    let withGuid = connection(serverId: "guid-1", url: "https://jf.example.com/")
    XCTAssertEqual(withGuid.stableHostId, "guid-1")

    let withoutGuid = connection(serverId: nil, url: "https://jf.example.com/")
    XCTAssertEqual(withoutGuid.stableHostId, withoutGuid.url.canonicalDedupKey)
  }
}
