//
//  ExternalStreamResolver.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Where a media-server item streams from, and what authorises the request.
public struct ExternalStreamSource: Equatable, Sendable {
  public let url: URL
  /// Custom headers first (reverse-proxy gates like Cloudflare Access), then the integration's
  /// own Authorization, which always wins on conflict.
  public let headers: [String: String]

  public init(url: URL, headers: [String: String]) {
    self.url = url
    self.headers = headers
  }
}

public protocol ExternalStreamResolving {
  /// The stream source for a resource, or nil when no saved connection on THIS device matches
  /// its host — which is what makes an item show as needing its server rather than silently
  /// streaming from whichever server happens to be configured.
  func streamSource(for resource: SimpleExternalResource) -> ExternalStreamSource?
}

/// Resolves against the connections saved in the keychain.
///
/// Injected rather than constructed inline so the resolution can be exercised in a test: this
/// logic used to sit in the middle of `PlaybackService.getPlayableChapters` with its own
/// `KeychainService()`, which meant nothing about streaming URLs, auth headers, or the
/// unresolved-host flag could be verified without a real keychain.
public struct ExternalStreamResolver: ExternalStreamResolving, BPLogger {
  private let keychain: KeychainServiceProtocol

  public init(keychain: KeychainServiceProtocol = KeychainService()) {
    self.keychain = keychain
  }

  public func streamSource(for resource: SimpleExternalResource) -> ExternalStreamSource? {
    switch ExternalResource.ProviderName(rawValue: resource.providerName) {
    case .jellyfin:
      guard
        let connection: JellyfinConnectionData = connection(for: resource, key: .jellyfinConnection)
      else { return nil }
      guard let url = URL(string: connection.buildDownloadUrl(providerId: resource.providerId)) else {
        // A matched server whose URL won't build is a defect, not a missing connection — but
        // the caller can only express "no source", so say so here.
        Self.logger.error("Jellyfin connection resolved but no stream URL could be built for \(resource.providerId)")
        return nil
      }

      return ExternalStreamSource(
        url: url,
        headers: authorizing(
          connection.customHeaders,
          with: "MediaBrowser Token=\"\(connection.accessToken)\""
        )
      )

    case .audiobookshelf:
      guard
        let connection: AudiobookShelfConnectionData = connection(for: resource, key: .audiobookshelfConnection)
      else { return nil }
      guard let url = URL(string: connection.buildAudiobookshelfDownloadUrl(providerId: resource.providerId)) else {
        Self.logger.error("AudiobookShelf connection resolved but no stream URL could be built for \(resource.providerId)")
        return nil
      }

      return ExternalStreamSource(
        url: url,
        headers: authorizing(connection.customHeaders, with: "Bearer \(connection.apiToken)")
      )

    default:
      return nil
    }
  }

  /// Resolved by stable host identity ONLY — no first-connection fallback. A resource whose
  /// host matches no saved server must surface as missing (connect-your-server), not stream
  /// from another instance where its provider id means nothing, or names a different book.
  /// Shared contract with the Android app.
  private func connection<T: IntegrationHostIdentifiable & Decodable>(
    for resource: SimpleExternalResource,
    key: KeychainKeys
  ) -> T? {
    let connections: [T] = (try? keychain.get(key)) ?? []

    return IntegrationHostResolver.connection(for: resource.hostId, in: connections)
  }

  /// Case-insensitive dedup: a user-configured lowercase "authorization" must not fight the
  /// integration's own header (same rule as JellyfinHeaderInjector).
  private func authorizing(
    _ customHeaders: [String: String],
    with authorization: String
  ) -> [String: String] {
    var headers = customHeaders.filter {
      $0.key.caseInsensitiveCompare("Authorization") != .orderedSame
    }
    headers["Authorization"] = authorization

    return headers
  }
}
