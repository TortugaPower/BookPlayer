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

  // MARK: - Paste decomposition

  /// Found on device: a URL pasted into the Host field split at the first slash of "http://",
  /// bracketed "http:" as if it were IPv6, and showed "[http:]//…" — with the original paste
  /// unrecoverable by the time Connect ran. Decomposition happens in the setter, where the paste
  /// actually arrives.
  func testPastedFullURLDistributesAcrossAllFields() {
    var address = IntegrationServerAddress(scheme: .https, host: "")

    address.hostField = "http://100.81.227.12:13378"

    XCTAssertEqual(address.scheme, .http, "the scheme control must flip to match the paste")
    XCTAssertEqual(address.host, "100.81.227.12")
    XCTAssertEqual(address.port, 13378)
    XCTAssertEqual(address.hostField, "100.81.227.12", "the field keeps only host + subpath")
    XCTAssertEqual(address.urlString, "http://100.81.227.12:13378")
  }

  func testPastedSchemelessHostPortAndPathDecompose() {
    var address = IntegrationServerAddress(scheme: .https, host: "")

    address.hostField = "example.com:8096/audiobookshelf"

    XCTAssertEqual(address.scheme, .https, "no scheme in the paste — the control keeps its setting")
    XCTAssertEqual(address.host, "example.com")
    XCTAssertEqual(address.port, 8096)
    XCTAssertEqual(address.path, "/audiobookshelf")
  }

  func testPastedBracketedIPv6WithPortDecomposes() {
    var address = IntegrationServerAddress(scheme: .http, host: "")

    address.hostField = "[::1]:8096"

    XCTAssertEqual(address.host, "[::1]")
    XCTAssertEqual(address.port, 8096)
    XCTAssertEqual(address.urlString, "http://[::1]:8096")
  }

  /// Mid-typing through a scheme ("http://" with nothing after it yet) must neither mangle the text
  /// nor produce a connectable URL.
  func testIncompleteSchemeHoldsRawTextWithoutAssembling() {
    var address = IntegrationServerAddress(scheme: .https, host: "")

    address.hostField = "http://"

    XCTAssertEqual(address.hostField, "http://", "raw text preserved while incomplete")
    XCTAssertNil(address.url, "Connect must stay disabled until the text resolves")
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

  // MARK: - Typing into the host field

  /// The field shows what was typed; the model normalizes for assembly. Echoing the normalized form
  /// back deleted the `/` a user had just typed, so a reverse-proxy subpath could only be pasted.
  func testTypingASubpathKeepsTheSlashInTheFieldAndNormalizesOnlyTheModel() {
    var address = IntegrationServerAddress(scheme: .https, host: "")

    XCTAssertEqual(address.applyHostField("media.example.com/"), "media.example.com/")
    XCTAssertEqual(address.path, "", "the model drops the trailing slash for assembly")
    XCTAssertEqual(address.urlString, "https://media.example.com")

    XCTAssertEqual(address.applyHostField("media.example.com/abs"), "media.example.com/abs")
    XCTAssertEqual(address.path, "/abs")
    XCTAssertEqual(address.urlString, "https://media.example.com/abs")
  }

  func testTypingAColonTowardAPortIsNeitherBracketedNorAssembled() {
    var address = IntegrationServerAddress(scheme: .https, host: "")

    XCTAssertEqual(address.applyHostField("media.example.com:"), "media.example.com:")
    XCTAssertEqual(address.host, "media.example.com:", "a hostname with a colon is not an IPv6 literal")
    XCTAssertNil(address.url, "Connect stays disabled until the text resolves")
    XCTAssertNil(address.port)
  }

  /// Once a digit follows the colon it is a `host:port`, and the port moves to its own row — the
  /// field text follows, so the port is not shown twice.
  func testAPortTypedIntoTheHostFieldPeelsOffAndRewritesTheField() {
    var address = IntegrationServerAddress(scheme: .https, host: "")

    XCTAssertEqual(address.applyHostField("media.example.com:8096/abs"), "media.example.com/abs")
    XCTAssertEqual(address.host, "media.example.com")
    XCTAssertEqual(address.port, 8096)
    XCTAssertEqual(address.path, "/abs")
  }

  func testTypingASchemeThroughIsNotMangledAndSnapsOnceItParses() {
    var address = IntegrationServerAddress(scheme: .https, host: "")

    XCTAssertEqual(address.applyHostField("http:"), "http:")
    XCTAssertEqual(address.host, "http:", "not bracketed as IPv6")
    XCTAssertNil(address.url)

    XCTAssertEqual(address.applyHostField("http://"), "http://")
    XCTAssertNil(address.url)

    XCTAssertEqual(address.applyHostField("http://x"), "x", "a parseable URL distributes: the field keeps host + subpath")
    XCTAssertEqual(address.scheme, .http)
    XCTAssertEqual(address.host, "x")
  }

  func testAPastedFullURLRewritesTheFieldToHostAndSubpath() {
    var address = IntegrationServerAddress(scheme: .https, host: "")

    XCTAssertEqual(address.applyHostField("http://100.81.227.12:13378/abs"), "100.81.227.12/abs")
    XCTAssertEqual(address.scheme, .http)
    XCTAssertEqual(address.port, 13378)
    XCTAssertEqual(address.urlString, "http://100.81.227.12:13378/abs")
  }

  func testABareIPv6LiteralStaysAsTypedInTheFieldButAssemblesBracketed() {
    var address = IntegrationServerAddress(scheme: .http, host: "")

    XCTAssertEqual(address.applyHostField("2001:db8::1"), "2001:db8::1")
    XCTAssertEqual(address.host, "[2001:db8::1]")
    XCTAssertEqual(address.urlString, "http://[2001:db8::1]")
    XCTAssertEqual(address.applyHostField("fe80::1%25en0"), "fe80::1%25en0", "a zone id does not stop the literal being recognized")
    XCTAssertEqual(address.host, "[fe80::1%25en0]")
  }

  func testATypedSpaceInASubpathIsEncodedInTheURLNotInTheField() {
    var address = IntegrationServerAddress(scheme: .https, host: "")

    XCTAssertEqual(address.applyHostField("x.example/audio books"), "x.example/audio books")
    XCTAssertEqual(address.urlString, "https://x.example/audio%20books")
  }

  func testOnlyIPv6LookingHostsGainBrackets() {
    XCTAssertEqual(IntegrationServerAddress(scheme: .http, host: "::1").host, "[::1]")
    XCTAssertEqual(IntegrationServerAddress(scheme: .http, host: "myserver.com:").host, "myserver.com:")
    XCTAssertEqual(IntegrationServerAddress(scheme: .http, host: "http:").host, "http:")
    XCTAssertEqual(IntegrationServerAddress(scheme: .http, host: "my:host:name").host, "my:host:name", "letters beyond hex are not an IPv6 literal")
  }
}
