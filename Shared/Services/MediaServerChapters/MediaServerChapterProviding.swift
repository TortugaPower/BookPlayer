//
//  MediaServerChapterProviding.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// The list-refresh entry point `ListSyncRefreshService` drives. One method, so the refresh
/// service can be tested with a recording stub instead of providers, a keychain or a network.
public protocol MediaServerChapterRefreshing: AnyObject {
  /// Fill in the chapters of the media-server books at one library level (root when nil) that
  /// still have none. Gated to the sync entitlement inside.
  func refreshChapters(at relativePath: String?) async
}

/// Reads one provider's chapters for its items.
///
/// `Sendable` so the refresh can ask the providers concurrently: a slow server of one provider
/// delays nobody else's.
public protocol MediaServerChapterProviding: Sendable {
  /// The chapters each resource's server reports, keyed by providerId.
  ///
  /// The resources may span SEVERAL servers of the same provider, so each is resolved to its
  /// own connection and asked there — a batch is not one request. A resource whose host
  /// resolves to nothing is simply absent from the result. An empty list is NOT a statement
  /// that the server has no chapters, which is why the ingest only ever adds them.
  func chapters(for resources: [SimpleExternalResource]) async throws -> [String: [ChapterMetadata]]
}

extension MediaServerChapterProviding {
  /// A batch that never throws and never asks for nothing: a provider builds a connection
  /// service and reads the keychain even for an empty list, and one provider failing can't
  /// fail the refresh.
  func chaptersIgnoringFailures(for resources: [SimpleExternalResource]) async -> [String: [ChapterMetadata]] {
    guard !resources.isEmpty else { return [:] }

    return (try? await chapters(for: resources)) ?? [:]
  }

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
/// `Sendable`, which the concurrent fan-out needs. The cost stays small anyway: the refresh only
/// reaches a provider for books that still have no chapters.
public struct JellyfinChapterProvider: MediaServerChapterProviding {
  public init() {}

  /// The import's own lookup, chapters included: it asks in batches, so a folder of hundreds of
  /// books can't overflow the URL.
  public func chapters(for resources: [SimpleExternalResource]) async throws -> [String: [ChapterMetadata]] {
    let service = JellyfinConnectionService()
    await service.setup()

    var chapters: [String: [ChapterMetadata]] = [:]

    for group in grouped(resources, by: await service.connections) {
      await service.useConnection(group.connection)

      for item in try await service.fetchItems(ids: group.resources.map(\.providerId)) {
        chapters[item.id] = item.chapters
      }
    }

    return chapters
  }
}

/// Same shape as `JellyfinChapterProvider`, including why it holds no connection service.
public struct AudiobookShelfChapterProvider: MediaServerChapterProviding {
  public init() {}

  /// `batch/get` returns expanded media, so the chapters are on the wire for every item.
  public func chapters(for resources: [SimpleExternalResource]) async throws -> [String: [ChapterMetadata]] {
    let service = AudiobookShelfConnectionService()
    await service.setup()

    var chapters: [String: [ChapterMetadata]] = [:]

    for group in grouped(resources, by: await service.connections) {
      await service.useConnection(group.connection)

      for item in try await service.fetchItems(ids: group.resources.map(\.providerId)) {
        chapters[item.id] = item.chapters
      }
    }

    return chapters
  }
}
