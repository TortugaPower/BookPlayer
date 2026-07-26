//
//  PKCE.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 25/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import CryptoKit
import Foundation

/// RFC 7636 Proof Key for Code Exchange parameters for a single authorization request.
///
/// Deliberately a plain value type with no networking, so the derivation can be pinned against the
/// known-answer vector in RFC 7636 Appendix B rather than only exercised end to end.
struct PKCE {
  /// The high-entropy secret held in memory and presented at the token exchange.
  let verifier: String
  /// `base64url(SHA256(verifier))`, sent with the authorization request.
  let challenge: String

  /// The only transform we offer. AudiobookShelf rejects anything else, and `plain` defeats the
  /// point of PKCE.
  static let challengeMethod = "S256"

  /// Generates a fresh verifier. 32 random bytes base64url-encode to 43 characters, which sits
  /// inside RFC 7636's required 43...128 range and uses only its unreserved character set.
  ///
  /// `SystemRandomNumberGenerator` is documented as drawing from the platform CSPRNG (the same
  /// kernel entropy source as `SecRandomCopyBytes`), and the full `UInt8` range is sampled, so
  /// there's no modulo bias.
  init(verifierByteCount: Int = 32) {
    var generator = SystemRandomNumberGenerator()
    let bytes = (0..<verifierByteCount).map { _ in
      UInt8.random(in: UInt8.min...UInt8.max, using: &generator)
    }
    self.init(verifier: Data(bytes).base64URLEncodedString())
  }

  /// Derives the challenge for a caller-supplied verifier. Exists so tests can pin a known vector.
  init(verifier: String) {
    self.verifier = verifier
    // A base64url verifier is unreserved ASCII, so its UTF-8 bytes are exactly its ASCII bytes —
    // which is what RFC 7636 specifies as the hash input.
    self.challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
  }

  /// An opaque value round-tripped through the authorization request to bind the callback to this
  /// flow, rejecting replayed or forged redirects. Not a secret, so no constant-time compare needed.
  static func makeState(byteCount: Int = 16) -> String {
    var generator = SystemRandomNumberGenerator()
    let bytes = (0..<byteCount).map { _ in
      UInt8.random(in: UInt8.min...UInt8.max, using: &generator)
    }
    return Data(bytes).base64URLEncodedString()
  }
}
