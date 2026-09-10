//
//  ExternalProgressProviding.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Where a media server says the user is in a book.
///
/// Provider-neutral on purpose: `handleSyncFromExternalResource` and the resume prompt both
/// only ever needed the position, the date and the finished flag, and typing that to one
/// provider's item is what left AudiobookShelf out of the library refresh.
public struct ExternalPlaybackProgress: Equatable, Sendable {
  public let currentTime: TimeInterval
  public let lastPlayedDate: Date?
  public let isFinished: Bool?

  public init(currentTime: TimeInterval, lastPlayedDate: Date?, isFinished: Bool? = nil) {
    self.currentTime = currentTime
    self.lastPlayedDate = lastPlayedDate
    self.isFinished = isFinished
  }
}

/// Reads one provider's playback position for a resource.
///
/// `Sendable` so the service can fan the providers out concurrently: an item linked to two
/// servers asks both at once instead of letting a slow one delay the other.
public protocol ExternalProgressProviding: Sendable {
  /// The position that resource's OWN server reports, or nil when no saved connection matches
  /// its host — the server isn't configured on this device, so there is nothing to compare.
  func progress(for resource: SimpleExternalResource) async throws -> ExternalPlaybackProgress?
}

/// Stateless: the connection service is built per call rather than held.
///
/// Holding one would save a keychain read, but it is `@MainActor`-isolated and therefore not
/// `Sendable`, which the concurrent fan-out needs. The cost that actually mattered — reading
/// the keychain on every playback start, including for plain local books — is gone anyway,
/// because the service only reaches a provider for an item that HAS media-server resources.
public struct JellyfinProgressProvider: ExternalProgressProviding {
  public init() {}

  public func progress(for resource: SimpleExternalResource) async throws -> ExternalPlaybackProgress? {
    let service = await JellyfinConnectionService()
    await service.setup()

    // Pin the resource's own server: the active connection may be a different instance where
    // this provider id doesn't exist, or worse, names another book.
    guard
      let connection = IntegrationHostResolver.connection(
        for: resource.hostId,
        in: await service.connections
      )
    else { return nil }

    await service.useConnection(connection)

    guard let item = try await service.fetchItem(for: resource.providerId) else { return nil }

    return ExternalPlaybackProgress(
      currentTime: TimeInterval(item.currentSeconds ?? 0),
      lastPlayedDate: item.lastPlayedDate,
      isFinished: item.isFinished
    )
  }
}

/// Same shape as `JellyfinProgressProvider`, including why it holds no connection service.
public struct AudiobookShelfProgressProvider: ExternalProgressProviding {
  public init() {}

  public func progress(for resource: SimpleExternalResource) async throws -> ExternalPlaybackProgress? {
    let service = await AudiobookShelfConnectionService()
    await service.setup()

    guard
      let connection = IntegrationHostResolver.connection(
        for: resource.hostId,
        in: await service.connections
      )
    else { return nil }

    await service.useConnection(connection)

    guard let item = try await service.fetchItem(for: resource.providerId) else { return nil }

    return ExternalPlaybackProgress(
      currentTime: item.currentTime ?? 0,
      lastPlayedDate: item.lastPlayedDate,
      isFinished: item.isFinished
    )
  }
}
