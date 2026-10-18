//
//  HardcoverServiceTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 18/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

/// Hardcover's API keys (`hc_pat_…`) come without the `Bearer` scheme its older tokens were copied with
class HardcoverServiceTests: XCTestCase {
  var sut: HardcoverService!
  var mockKeychain: KeychainServiceMock!

  override func setUp() {
    mockKeychain = KeychainServiceMock()
    sut = HardcoverService()
    sut.setup(
      libraryService: LibraryServiceProtocolMock(),
      syncService: SyncServiceProtocolMock(),
      keychain: mockKeychain
    )
  }

  func testApiKeyKeepsABareKey() {
    XCTAssertEqual(HardcoverService.apiKey(from: "hc_pat_abc123"), "hc_pat_abc123")
  }

  func testApiKeyDropsTheBearerScheme() {
    XCTAssertEqual(HardcoverService.apiKey(from: "Bearer hc_pat_abc123"), "hc_pat_abc123")
    XCTAssertEqual(HardcoverService.apiKey(from: "bearer   eyJhbGciOiJSUzI1NiJ9"), "eyJhbGciOiJSUzI1NiJ9")
    XCTAssertEqual(HardcoverService.apiKey(from: "BEARER\thc_pat_abc123"), "hc_pat_abc123")
  }

  func testApiKeyTrimsWhitespaceAndNewlines() {
    XCTAssertEqual(HardcoverService.apiKey(from: "  Bearer hc_pat_abc123 \n"), "hc_pat_abc123")
  }

  func testApiKeyOfTheSchemeAloneIsEmpty() {
    XCTAssertEqual(HardcoverService.apiKey(from: "Bearer"), "")
    XCTAssertEqual(HardcoverService.apiKey(from: "Bearer "), "")
    XCTAssertEqual(HardcoverService.apiKey(from: "   "), "")
  }

  func testApiKeyKeepsAKeyThatOnlyStartsWithBearer() {
    XCTAssertEqual(HardcoverService.apiKey(from: "bearerish_key"), "bearerish_key")
  }

  func testSavingAPastedBearerTokenStoresTheBareKey() throws {
    sut.authorization = "Bearer hc_pat_abc123"

    XCTAssertEqual(try mockKeychain.get(.hardcoverToken), "hc_pat_abc123")
    XCTAssertEqual(sut.authorization, "hc_pat_abc123")
  }

  func testATokenSavedWithItsBearerSchemeReadsBare() throws {
    try mockKeychain.set("Bearer eyJhbGciOiJSUzI1NiJ9", key: .hardcoverToken)

    XCTAssertEqual(sut.authorization, "eyJhbGciOiJSUzI1NiJ9")
  }

  func testSavingTheSchemeAloneRemovesTheToken() throws {
    sut.authorization = "hc_pat_abc123"
    sut.authorization = "Bearer "

    XCTAssertNil(try mockKeychain.get(.hardcoverToken))
    XCTAssertNil(sut.authorization)
  }
}
