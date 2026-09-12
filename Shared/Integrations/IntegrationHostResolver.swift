//
//  IntegrationHostResolver.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// A saved media-server connection that can be matched against a synced external resource's
/// `hostId`. Both `JellyfinConnectionData` and `AudiobookShelfConnectionData` conform.
public protocol IntegrationHostIdentifiable {
  /// The server's own stable id (Jellyfin `System/Info.Id`, ABS login `server.id`), captured at
  /// sign-in. Nil for connections saved before the server ever reported one.
  var serverId: String? { get }
  var url: URL { get }
}

extension IntegrationHostIdentifiable {
  /// The value written as `hostId` on external resources this connection imports — the
  /// cross-device server identity. Contract shared with the Android app (its
  /// `ExternalServiceUtils.stableHostId`): the server GUID when known, else the canonical
  /// URL key (never the raw absolute string, so trailing-slash/port/case variants of one
  /// logical server produce the same identity on every device).
  public var stableHostId: String {
    serverId ?? url.canonicalDedupKey
  }
}

/// Mirrors the Android app's `ExternalServiceUtils.serverForResource` resolution contract:
///  1. stable server GUID, case-insensitive (Jellyfin reports lowercase hex, ABS uppercase UUIDs —
///     casing must never break the match);
///  2. else canonical URL key (covers GUID-less servers and URL-fallback hostIds);
///  3. else **nil** — deliberately NO first-connection fallback. Guessing a server streams the
///     wrong file or pushes progress to the wrong server when ids collide across instances;
///     an unresolvable host must surface as "connect your server", not silently misroute.
public enum IntegrationHostResolver {
  public static func connection<C: IntegrationHostIdentifiable>(
    for hostId: String?,
    in connections: [C]
  ) -> C? {
    guard let hostId, !hostId.isEmpty else { return nil }
    if let byServerId = connections.first(where: {
      $0.serverId?.caseInsensitiveCompare(hostId) == .orderedSame
    }) {
      return byServerId
    }
    return connections.first(where: { $0.url.canonicalDedupKey == hostId })
  }

  /// Display strings for each resource's host, keyed by providerId: the saved connection's
  /// URL when the host resolves, else the raw `hostId` — which is all a device that never
  /// added the server knows about it.
  ///
  /// Each provider decodes its own connection type from its own keychain key; the generic
  /// `hostURL` is what lets one switch cover them all.
  public static func hostDisplayStrings(
    for resources: [SimpleExternalResource],
    keychain: KeychainServiceProtocol
  ) -> [String: String] {
    resources.reduce(into: [:]) { hosts, resource in
      let hostId = resource.hostId ?? ""
      let url: URL? =
        switch ExternalResource.ProviderName(rawValue: resource.providerName) {
        case .jellyfin:
          hostURL(for: hostId, key: .jellyfinConnection, of: [JellyfinConnectionData].self, keychain: keychain)
        case .audiobookshelf:
          hostURL(for: hostId, key: .audiobookshelfConnection, of: [AudiobookShelfConnectionData].self, keychain: keychain)
        default:
          nil
        }
      hosts[resource.providerId] = url?.absoluteString ?? hostId
    }
  }

  private static func hostURL<T: IntegrationHostIdentifiable & Decodable>(
    for hostId: String,
    key: KeychainKeys,
    of type: [T].Type,
    keychain: KeychainServiceProtocol
  ) -> URL? {
    let connections: [T] = (try? keychain.get(key)) ?? []
    return connection(for: hostId, in: connections)?.url
  }
}
