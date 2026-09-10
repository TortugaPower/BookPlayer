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

  /// Positions for many resources at once, keyed by providerId.
  ///
  /// The resources may span SEVERAL servers of the same provider, so each is resolved to its
  /// own connection and queried there — a batch is not one request. A resource whose host
  /// resolves to nothing is simply absent from the result.
  func progress(forBatch resources: [SimpleExternalResource]) async throws -> [String: ExternalPlaybackProgress]
}

extension ExternalProgressProviding {
  /// Groups resources by the connection that owns them, so a caller can query each server
  /// with only its own ids. Shared by both adapters: the grouping rule is the resolution
  /// contract, not provider-specific.
  func grouped<C: IntegrationHostIdentifiable>(
    _ resources: [SimpleExternalResource],
    by connections: [C]
  ) -> [(connection: C, resources: [SimpleExternalResource])] {
    var byConnectionIndex: [Int: [SimpleExternalResource]] = [:]

    for resource in resources {
      guard
        let connection = IntegrationHostResolver.connection(for: resource.hostId, in: connections),
        let index = connections.firstIndex(where: { $0.stableHostId == connection.stableHostId })
      else { continue }

      byConnectionIndex[index, default: []].append(resource)
    }

    return byConnectionIndex.map { (connections[$0.key], $0.value) }
  }
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

  public func progress(
    forBatch resources: [SimpleExternalResource]
  ) async throws -> [String: ExternalPlaybackProgress] {
    let service = await JellyfinConnectionService()
    await service.setup()

    var progress: [String: ExternalPlaybackProgress] = [:]

    for group in grouped(resources, by: await service.connections) {
      await service.useConnection(group.connection)

      let items = try await service.updateItemsFromJellyfin(group.resources)
      for (providerId, item) in items {
        progress[providerId] = ExternalPlaybackProgress(
          currentTime: TimeInterval(item.currentSeconds ?? 0),
          lastPlayedDate: item.lastPlayedDate,
          isFinished: item.isFinished
        )
      }
    }

    return progress
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

  public func progress(
    forBatch resources: [SimpleExternalResource]
  ) async throws -> [String: ExternalPlaybackProgress] {
    let service = await AudiobookShelfConnectionService()
    await service.setup()

    var progress: [String: ExternalPlaybackProgress] = [:]

    for group in grouped(resources, by: await service.connections) {
      await service.useConnection(group.connection)

      for item in try await service.fetchItems(ids: group.resources.map(\.providerId)) {
        progress[item.id] = ExternalPlaybackProgress(
          currentTime: item.currentTime ?? 0,
          lastPlayedDate: item.lastPlayedDate,
          isFinished: item.isFinished
        )
      }
    }

    return progress
  }
}
