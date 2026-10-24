//
//  ListSyncRefreshService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

enum BPSyncRefreshError: Error {
  /// There are queued tasks and can't fetch remote data
  case scheduledTasks
  case disabled
}

/// Refreshes one library level from every remote it has: the BookPlayer cloud (contents and
/// last-played book), the user's synced preferences, and the chapters the level's media
/// servers report for streamed books that have none. Every caller — list appear, pull-to-refresh, sync activation, CarPlay —
/// goes through `syncList(at:)`, so no entry point can forget a step.
final class ListSyncRefreshService: BPLogger, ObservableObject {
  let playerManager: PlayerManagerProtocol
  let syncService: SyncServiceProtocol
  let playerLoaderService: PlayerLoaderService
  let preferencesService: PreferencesSyncServiceProtocol
  let chapterRefreshService: MediaServerChapterRefreshing

  init(
    playerManager: PlayerManagerProtocol,
    syncService: SyncServiceProtocol,
    playerLoaderService: PlayerLoaderService,
    preferencesService: PreferencesSyncServiceProtocol,
    chapterRefreshService: MediaServerChapterRefreshing
  ) {
    self.playerManager = playerManager
    self.syncService = syncService
    self.playerLoaderService = playerLoaderService
    self.preferencesService = preferencesService
    self.chapterRefreshService = chapterRefreshService
  }

  func syncList(at relativePath: String?) async throws {
    // Pref pull runs in parallel with content sync and is independent of the
    // item-sync queue state — kick it off first so a queue-blocked content
    // sync doesn't skip the pref refresh.
    async let prefPull: Void = { await preferencesService.pullFromServer(force: false) }()

    let hasRunFirstSync = syncService.hasRunFirstSync
    do {
      if let relativePath {
        // Until the first sync has registered this device's items (after signing in, or on
        // coming back from a lapse), a folder's listing would delete the ones the server
        // hasn't seen yet, such as books imported while sync was off
        if hasRunFirstSync {
          try await syncService.syncListContents(at: relativePath)
        }
      } else if hasRunFirstSync {
        try await syncService.syncListContents(at: nil)
      } else {
        try await syncService.syncLibraryContents()
      }
    } catch BPSyncError.reloadLastBook(let relativePath) {
      try await reloadLastBook(relativePath: relativePath)
    } catch BPSyncError.differentLastBook(let relativePath) {
      try await setSyncedLastPlayedItem(relativePath: relativePath)
    } catch {
      Self.logger.trace("Sync contents error: \(error.localizedDescription)")
    }

    // Strictly AFTER the cloud step, never alongside it: the sync wrote this level on the
    // background context and the chapters ingest writes on the view context, and with no
    // merge policy set the two must not overlap. Runs whatever the cloud outcome was — the
    // media servers are separate hosts, and the refresh is gated on the entitlement inside.
    await chapterRefreshService.refreshChapters(at: relativePath)

    _ = await prefPull

    // The weekly / became-PRO missing-items pass, off the refresh's path: a pull-to-refresh
    // spinner shouldn't wait on it (it returns at once when nothing is due)
    if relativePath == nil {
      let syncService = syncService
      Task { await syncService.scheduleMissingItemsIfNeeded() }
    }
  }

  @MainActor
  private func reloadLastBook(relativePath: String) async throws {
    let wasPlaying = playerManager.isPlaying
    playerManager.stop()

    try await playerLoaderService.loadPlayer(
      relativePath,
      autoplay: wasPlaying
    )
  }

  @MainActor
  private func setSyncedLastPlayedItem(relativePath: String) async throws {
    /// Only continue overriding local book if it's not currently playing
    guard playerManager.isPlaying == false else { return }

    await syncService.setLibraryLastBook(with: relativePath)

    try await playerLoaderService.loadPlayer(
      relativePath,
      autoplay: false
    )
  }
}
