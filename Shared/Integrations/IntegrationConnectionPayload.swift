//
//  IntegrationConnectionPayload.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 25/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// A saved media-server connection, as persisted in the Keychain.
///
/// `token` is deliberately a **computed** projection of each integration's own stored property
/// (`apiToken` for AudiobookShelf, `accessToken` for Jellyfin) rather than a stored member of this
/// protocol. Both integrations have already shipped, so renaming or introducing a stored property
/// would change the `Codable` representation and silently fail to decode the records already in
/// users' Keychains — signing everyone out. Conformance must stay purely additive: no new stored
/// properties, no `CodingKeys` changes.
protocol IntegrationConnectionPayload: Codable, Identifiable {
  var id: String { get }
  var url: URL { get }
  var userID: String { get }
  /// The integration's bearer/access token. Computed — never encoded under this name.
  var token: String { get }
  var selectedLibraryId: String? { get set }
  var customHeaders: [String: String] { get set }
}

extension IntegrationConnectionPayload {
  /// A record with no user or no token can't authenticate, so it is dropped when loading.
  var isUsable: Bool { !userID.isEmpty && !token.isEmpty }

  /// Two records describe the same account when the canonicalized server URL and the user match.
  /// Goes through `canonicalDedupKey` so `https://host:443/` and `https://host` don't produce
  /// duplicate connections for one account.
  func isSameAccount(as otherURL: URL, userID otherUserID: String) -> Bool {
    url.canonicalDedupKey == otherURL.canonicalDedupKey && userID == otherUserID
  }
}
