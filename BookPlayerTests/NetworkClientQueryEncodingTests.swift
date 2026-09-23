//
//  NetworkClientQueryEncodingTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayerKit

/// GET parameters travel as `[String: Any]`. An optional stored as `Any` used to be
/// interpolated into the query string as `Optional("…")` — or the literal `nil` —
/// which is what the API received for every `uuid` on `/v1/library` for years and
/// silently ignored. The encoder must unwrap optionals and drop absent values.
final class NetworkClientQueryEncodingTests: XCTestCase {
  func testOptionalGetParametersAreUnwrappedAndAbsentOnesDropped() throws {
    let client = NetworkClient()
    let uuid: String? = "2C2D0F44-1111-4111-8111-111111111111"
    let missing: String? = nil

    let request = try client.buildURLRequest(
      path: "/v1/library",
      method: .get,
      parameters: [
        "relativePath": "Folder/",
        "sign": true,
        "uuid": uuid as Any,
        "missing": missing as Any,
      ]
    )

    let url = try XCTUnwrap(request.url)
    let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

    XCTAssertEqual(byName["uuid"], uuid, "the wrapped value, not Optional(\"…\")")
    XCTAssertEqual(byName["relativePath"], "Folder/")
    XCTAssertEqual(byName["sign"], "true")
    XCTAssertNil(byName["missing"], "a nil optional is omitted, not sent as the string \"nil\"")
    XCTAssertFalse(url.absoluteString.contains("Optional"))
    XCTAssertFalse(url.absoluteString.contains("nil"))
  }
}
