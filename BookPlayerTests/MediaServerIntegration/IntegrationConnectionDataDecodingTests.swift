//
//  IntegrationConnectionDataDecodingTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

/// Guards the Keychain wire format for both integrations' saved connections.
///
/// `IntegrationConnectionPayload` exposes a `token` property, but each type satisfies it with a
/// *computed* projection of its own stored field (`apiToken` / `accessToken`). If someone later
/// "tidies" that into a stored property, or renames a `CodingKey`, these fixtures stop decoding — and
/// the real-world symptom is every existing user silently signed out of their media server on update,
/// which no other test in the suite would catch.
final class IntegrationConnectionDataDecodingTests: XCTestCase {
  private let decoder = JSONDecoder()

  // MARK: - AudiobookShelf

  /// The shape written by the shipped multi-server implementation.
  private let audiobookshelfJSON = """
    [{
      "id": "3E4E6C1E-1D2B-4B7A-9E4C-4A1A2B3C4D5E",
      "url": "https://abs.example.com",
      "serverName": "Home",
      "userID": "usr_abc123",
      "userName": "hana",
      "apiToken": "eyJhbGciOiJIUzI1NiJ9.payload.signature",
      "selectedLibraryId": "lib_xyz789",
      "customHeaders": { "CF-Access-Client-Id": "client-id" }
    }]
    """

  func testAudiobookShelfConnectionDecodesFromShippedFormat() throws {
    let decoded = try decoder.decode([AudiobookShelfConnectionData].self, from: Data(audiobookshelfJSON.utf8))

    let connection = try XCTUnwrap(decoded.first)
    XCTAssertEqual(connection.id, "3E4E6C1E-1D2B-4B7A-9E4C-4A1A2B3C4D5E")
    XCTAssertEqual(connection.url, URL(string: "https://abs.example.com"))
    XCTAssertEqual(connection.serverName, "Home")
    XCTAssertEqual(connection.userID, "usr_abc123")
    XCTAssertEqual(connection.userName, "hana")
    XCTAssertEqual(connection.apiToken, "eyJhbGciOiJIUzI1NiJ9.payload.signature")
    XCTAssertEqual(connection.selectedLibraryId, "lib_xyz789")
    XCTAssertEqual(connection.customHeaders, ["CF-Access-Client-Id": "client-id"])
    // The protocol requirement must read through to the stored field, not a new key.
    XCTAssertEqual(connection.token, connection.apiToken)
  }

  /// Pre-multi-server records were a bare object. `IntegrationConnectionStore.reload()` migrates them,
  /// so the single-object form has to keep decoding too.
  func testAudiobookShelfConnectionDecodesLegacySingleObjectForm() throws {
    let json = """
      {
        "url": "https://abs.example.com",
        "serverName": "Home",
        "userID": "usr_abc123",
        "userName": "hana",
        "apiToken": "token"
      }
      """

    let connection = try decoder.decode(AudiobookShelfConnectionData.self, from: Data(json.utf8))

    XCTAssertEqual(connection.apiToken, "token")
    // Absent optionals must default rather than fail the decode.
    XCTAssertNil(connection.selectedLibraryId)
    XCTAssertEqual(connection.customHeaders, [:])
    // A missing id is backfilled so the record stays usable.
    XCTAssertFalse(connection.id.isEmpty)
  }

  func testAudiobookShelfConnectionRoundTrips() throws {
    let decoded = try decoder.decode([AudiobookShelfConnectionData].self, from: Data(audiobookshelfJSON.utf8))
    let reEncoded = try JSONEncoder().encode(decoded)
    let reDecoded = try decoder.decode([AudiobookShelfConnectionData].self, from: reEncoded)

    XCTAssertEqual(reDecoded.first?.apiToken, decoded.first?.apiToken)
    XCTAssertEqual(reDecoded.first?.id, decoded.first?.id)
    XCTAssertEqual(reDecoded.first?.selectedLibraryId, decoded.first?.selectedLibraryId)
  }

  /// The token must never be encoded under the protocol's generic name — that would be the rename this
  /// whole design avoids.
  func testAudiobookShelfConnectionDoesNotEncodeAGenericTokenKey() throws {
    let decoded = try decoder.decode([AudiobookShelfConnectionData].self, from: Data(audiobookshelfJSON.utf8))
    let encoded = try JSONEncoder().encode(try XCTUnwrap(decoded.first))
    let object = try XCTUnwrap(
      try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )

    XCTAssertNotNil(object["apiToken"])
    XCTAssertNil(object["token"], "`token` is a computed projection and must not be persisted")
  }

  // MARK: - Jellyfin

  private let jellyfinJSON = """
    [{
      "id": "9F8E7D6C-5B4A-3928-1706-F5E4D3C2B1A0",
      "url": "https://jellyfin.example.com:8096",
      "serverName": "Media",
      "userID": "0a1b2c3d4e5f",
      "userName": "hana",
      "accessToken": "abcdef0123456789",
      "selectedLibraryId": "lib-audiobooks",
      "customHeaders": {}
    }]
    """

  func testJellyfinConnectionDecodesFromShippedFormat() throws {
    let decoded = try decoder.decode([JellyfinConnectionData].self, from: Data(jellyfinJSON.utf8))

    let connection = try XCTUnwrap(decoded.first)
    XCTAssertEqual(connection.id, "9F8E7D6C-5B4A-3928-1706-F5E4D3C2B1A0")
    XCTAssertEqual(connection.url, URL(string: "https://jellyfin.example.com:8096"))
    XCTAssertEqual(connection.userID, "0a1b2c3d4e5f")
    XCTAssertEqual(connection.accessToken, "abcdef0123456789")
    XCTAssertEqual(connection.selectedLibraryId, "lib-audiobooks")
    XCTAssertEqual(connection.token, connection.accessToken)
  }

  func testJellyfinConnectionDoesNotEncodeAGenericTokenKey() throws {
    let decoded = try decoder.decode([JellyfinConnectionData].self, from: Data(jellyfinJSON.utf8))
    let encoded = try JSONEncoder().encode(try XCTUnwrap(decoded.first))
    let object = try XCTUnwrap(
      try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )

    XCTAssertNotNil(object["accessToken"])
    XCTAssertNil(object["token"], "`token` is a computed projection and must not be persisted")
  }

  // MARK: - Usability filter

  func testRecordsWithoutAUsableTokenAreRejected() throws {
    // `IntegrationConnectionStore.reload()` drops these; a record with no token only yields 401 loops.
    let json = """
      {
        "url": "https://abs.example.com",
        "serverName": "Home",
        "userID": "usr_abc123",
        "userName": "hana",
        "apiToken": ""
      }
      """

    let connection = try decoder.decode(AudiobookShelfConnectionData.self, from: Data(json.utf8))

    XCTAssertFalse(connection.isUsable)
  }
}
