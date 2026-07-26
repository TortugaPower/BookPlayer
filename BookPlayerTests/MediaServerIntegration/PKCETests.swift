//
//  PKCETests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

final class PKCETests: XCTestCase {
  /// The known-answer vector published in RFC 7636 Appendix B. This is the test that would actually
  /// catch a broken S256 derivation — a round-trip against our own code would pass either way.
  func testChallengeMatchesRFC7636AppendixBVector() {
    let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

    XCTAssertEqual(pkce.challenge, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
  }

  func testChallengeMethodIsS256() {
    // `plain` would defeat the point of PKCE, and AudiobookShelf rejects anything else.
    XCTAssertEqual(PKCE.challengeMethod, "S256")
  }

  func testGeneratedVerifierIsWithinRFCLengthRange() {
    let pkce = PKCE()

    // RFC 7636 §4.1 requires 43...128 characters; 32 random bytes base64url-encode to exactly 43.
    XCTAssertEqual(pkce.verifier.count, 43)
  }

  func testGeneratedVerifierUsesOnlyUnreservedCharacters() {
    // base64url output must never contain `+`, `/` or `=`, or it would need percent-encoding in a
    // query string and stop round-tripping.
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    for _ in 0..<32 {
      let verifier = PKCE().verifier
      XCTAssertNil(
        verifier.rangeOfCharacter(from: allowed.inverted),
        "verifier contained a reserved character: \(verifier)"
      )
    }
  }

  func testGeneratedVerifiersAreDistinct() {
    let verifiers = Set((0..<64).map { _ in PKCE().verifier })

    // A fixed or low-entropy verifier would let an attacker who intercepts the code redeem it.
    XCTAssertEqual(verifiers.count, 64)
  }

  func testChallengeIsDeterministicForAGivenVerifier() {
    let verifier = PKCE().verifier

    XCTAssertEqual(PKCE(verifier: verifier).challenge, PKCE(verifier: verifier).challenge)
  }

  func testStateIsRandomAndURLSafe() {
    let states = Set((0..<64).map { _ in PKCE.makeState() })
    XCTAssertEqual(states.count, 64)

    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    XCTAssertNil(PKCE.makeState().rangeOfCharacter(from: allowed.inverted))
  }
}
