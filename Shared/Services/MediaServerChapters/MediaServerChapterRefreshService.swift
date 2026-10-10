//
//  MediaServerChapterRefreshService.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Fills in the chapters of streamed media-server books that have none.
///
/// A book streamed on this device gets its chapters at import. One that arrives through
/// BookPlayer's own sync (streamed on another device) has none, and nothing here ever opens its
/// file, so the list refresh asks its server. Driven by `ListSyncRefreshService.syncList` right
/// after the cloud sync of the same level, on the links that sync just reconciled. Gated to the
/// sync entitlement (`lite` or `pro`, `hasSyncEnabled()`), read live on every call: only a synced
/// library brings such rows.
public final class MediaServerChapterRefreshService: MediaServerChapterRefreshing {
  private var libraryService: LibraryServiceProtocol!
  private var accountService: AccountServiceProtocol!
  private var providers: [ExternalResource.ProviderName: MediaServerChapterProviding] = [:]

  public init() {}

  public func setup(
    libraryService: LibraryServiceProtocol,
    accountService: AccountServiceProtocol,
    providers: [ExternalResource.ProviderName: MediaServerChapterProviding] = [
      .jellyfin: JellyfinChapterProvider(),
      .audiobookshelf: AudiobookShelfChapterProvider(),
    ]
  ) {
    self.libraryService = libraryService
    self.accountService = accountService
    self.providers = providers
  }

  /// Resource-first: one background query returns only the links of the level's books that
  /// still lack chapters, so in the steady state nothing is asked at all, and the main thread
  /// does nothing here but the ingest. Every provider is asked in parallel and each folds its
  /// own answers in.
  public func refreshChapters(at relativePath: String?) async {
    guard accountService.hasSyncEnabled() else { return }

    let resources = await libraryService.findChapterlessMediaServerResources(at: relativePath)
    guard !resources.isEmpty else { return }

    let byProvider = Dictionary(grouping: resources) { $0.providerName }

    await withTaskGroup(of: (String, [String: [ChapterMetadata]]).self) { group in
      for (providerName, providerResources) in byProvider {
        guard
          let name = ExternalResource.ProviderName(rawValue: providerName),
          let provider = providers[name]
        else { continue }

        group.addTask {
          (providerName, await provider.chaptersIgnoringFailures(for: providerResources))
        }
      }

      for await (providerName, chapters) in group where !chapters.isEmpty {
        await libraryService.storeMediaServerChapters(
          providerName: providerName,
          chaptersByProviderId: chapters
        )
      }
    }
  }
}
