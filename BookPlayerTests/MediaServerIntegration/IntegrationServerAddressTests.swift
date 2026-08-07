//
//  IntegrationServerAddressTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
import XCTest

/// The address model is the ground the new connection flow stands on: parsing prefills the form from a
/// stored URL, assembly builds the URL the client actually connects to. A quiet mistake in either
/// direction misconnects without an error, so both directions are pinned here.
final class IntegrationServerAddressTests: XCTestCase {
  // MARK: - Parsing

  func testParsesADirectAddress() {
    let address = IntegrationServerAddress(parsing: "https://ds224plus.example.ts.net")

    XCTAssertEqual(address?.scheme, .https)
    XCTAssertEqual(address?.host, "ds224plus.example.ts.net")
    XCTAssertEqual(address?.path, "")
    XCTAssertNil(address?.port)
  }

  func testParsesHostPortAndUppercaseScheme() {
    let address = IntegrationServerAddress(parsing: "HTTP://192.168.1.5:8096")

    XCTAssertEqual(address?.scheme, .http)
    XCTAssertEqual(address?.host, "192.168.1.5")
    XCTAssertEqual(address?.port, 8096)
  }

  /// The reverse-proxy case: the subpath must survive, or those installs cannot be represented.
  func testParsesAReverseProxySubpath() {
    let address = IntegrationServerAddress(parsing: "https://media.example.com/audiobookshelf")

    XCTAssertEqual(address?.host, "media.example.com")
    XCTAssertEqual(address?.path, "/audiobookshelf")
    XCTAssertEqual(address?.hostField, "media.example.com/audiobookshelf")
  }

  func testTrailingSlashesNormalizeAway() {
    XCTAssertEqual(IntegrationServerAddress(parsing: "https://example.com/")?.path, "")
    XCTAssertEqual(IntegrationServerAddress(parsing: "https://example.com/abs///")?.path, "/abs")
  }

  func testWhitespaceAroundAPasteIsTrimmed() {
    let address = IntegrationServerAddress(parsing: "  https://example.com:5006 \n")

    XCTAssertEqual(address?.host, "example.com")
    XCTAssertEqual(address?.port, 5006)
  }

  /// Only http/https can reach a media server; anything else parsing "successfully" would let a stored
  /// or pasted `javascript:`/`file:` string round-trip into a connectable — and linkifiable — value.
  func testRejectsNonWebSchemes() {
    for bad in ["ftp://example.com", "javascript:alert(1)", "file:///etc/hosts", "ws://example.com"] {
      XCTAssertNil(IntegrationServerAddress(parsing: bad), "should reject: \(bad)")
    }
  }

  /// A server *base* URL has no userinfo, query, or fragment. Dropping them silently would connect
  /// somewhere other than what the user pasted, so the parse refuses instead.
  func testRejectsComponentsABaseURLCannotCarry() {
    for bad in [
      "https://user:pass@example.com",
      "https://example.com?redirect=1",
      "https://example.com/abs#section",
    ] {
      XCTAssertNil(IntegrationServerAddress(parsing: bad), "should reject: \(bad)")
    }
  }

  func testRejectsSchemelessEmptyAndOutOfRangePorts() {
    XCTAssertNil(IntegrationServerAddress(parsing: "example.com:8096"))
    XCTAssertNil(IntegrationServerAddress(parsing: ""))
    XCTAssertNil(IntegrationServerAddress(parsing: "https://"))
    XCTAssertNil(IntegrationServerAddress(parsing: "http://example.com:0"))
    XCTAssertNil(IntegrationServerAddress(parsing: "http://example.com:70000"))
  }

  // MARK: - Assembly

  /// The rule the whole port UX hangs on: the placeholder is an example, never a substitute. Empty
  /// port → no port in the URL.
  func testEmptyPortProducesNoPort() {
    let address = IntegrationServerAddress(scheme: .https, host: "media.example.com", path: "/audiobookshelf")

    XCTAssertEqual(address.urlString, "https://media.example.com/audiobookshelf")
  }

  func testTypedPortIsIncludedVerbatim() {
    let address = IntegrationServerAddress(scheme: .http, host: "100.81.227.12", port: 13378)

    XCTAssertEqual(address.urlString, "http://100.81.227.12:13378")
  }

  /// A typed port equal to the scheme default still appears — assembly is strict, not canonicalizing.
  func testSchemeDefaultPortIsNotStripped() {
    let address = IntegrationServerAddress(scheme: .https, host: "example.com", port: 443)

    XCTAssertEqual(address.urlString, "https://example.com:443")
  }

  func testEmptyHostAssemblesToNil() {
    XCTAssertNil(IntegrationServerAddress(scheme: .https, host: "").url)
  }

  // MARK: - Round trips

  /// parse → assemble must reproduce a canonical input byte-for-byte: this pair prefills the form from
  /// the stored URL and then rebuilds it, and any drift here rewrites connections nobody touched.
  func testCanonicalRoundTrips() {
    for original in [
      "https://ds224plus.example.ts.net:8096",
      "http://192.168.1.5:13378",
      "https://media.example.com/audiobookshelf",
      "https://media.example.com:8443/abs",
      "http://jellyfin.local",
    ] {
      XCTAssertEqual(IntegrationServerAddress(parsing: original)?.urlString, original)
    }
  }

  /// `URLComponents.host` keeps IPv6 brackets on this Foundation, and assembly *requires* them — a
  /// bare `::1` host assembles to nil. The model stores the bracketed form and normalizes a bare
  /// literal on the way in, so neither construction path can produce a silently-nil URL.
  /// The case a decoded-path implementation gets wrong: `%2F` inside a segment is indistinguishable
  /// from a separator once decoded, so parse → assemble would rewrite the URL. Found by probing, not
  /// by review — keep this pinned.
  func testEncodedSlashInAPathSegmentRoundTrips() {
    let address = IntegrationServerAddress(parsing: "https://media.example.com/a%2Fb")

    XCTAssertEqual(address?.path, "/a%2Fb")
    XCTAssertEqual(address?.urlString, "https://media.example.com/a%2Fb")
  }

  func testEncodedSpaceRoundTripsAndRawTypedSpaceEncodesOnce() {
    let parsed = IntegrationServerAddress(parsing: "https://x.example/audio%20books")
    XCTAssertEqual(parsed?.urlString, "https://x.example/audio%20books")

    var typed = IntegrationServerAddress(scheme: .https, host: "")
    typed.hostField = "x.example/audio books"
    XCTAssertEqual(typed.path, "/audio%20books", "raw typed text encodes exactly once — no double-encoding")
    XCTAssertEqual(typed.urlString, "https://x.example/audio%20books")
  }

  func testIPv6LiteralRoundTripsWithBrackets() {
    let address = IntegrationServerAddress(parsing: "http://[::1]:8096")

    XCTAssertEqual(address?.host, "[::1]")
    XCTAssertEqual(address?.port, 8096)
    XCTAssertEqual(address?.urlString, "http://[::1]:8096")
  }

  func testBareIPv6LiteralGainsItsBrackets() {
    let direct = IntegrationServerAddress(scheme: .http, host: "::1", port: 8096)
    XCTAssertEqual(direct.urlString, "http://[::1]:8096")

    var viaField = IntegrationServerAddress(scheme: .http, host: "")
    viaField.hostField = "2001:db8::1/jellyfin"
    XCTAssertEqual(viaField.host, "[2001:db8::1]")
    XCTAssertEqual(viaField.path, "/jellyfin")
  }

  // MARK: - The combined host field

  func testHostFieldSetterSplitsAtTheFirstSlash() {
    var address = IntegrationServerAddress(scheme: .https, host: "old.example.com")

    address.hostField = "media.example.com/audiobookshelf/"

    XCTAssertEqual(address.host, "media.example.com")
    XCTAssertEqual(address.path, "/audiobookshelf")
  }

  func testHostFieldSetterClearsAStalePath() {
    var address = IntegrationServerAddress(scheme: .https, host: "media.example.com", path: "/abs")

    address.hostField = "direct.example.com"

    XCTAssertEqual(address.host, "direct.example.com")
    XCTAssertEqual(address.path, "")
  }
}
