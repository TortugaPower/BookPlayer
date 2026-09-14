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
/// last-played book), the user's synced preferences, and the positions the level's media
/// servers report. Every caller — list appear, pull-to-refresh, sync activation, CarPlay —
/// goes through `syncList(at:)`, so no entry point can forget a step.
final class ListSyncRefreshService: BPLogger, ObservableObject {
  let playerManager: PlayerManagerProtocol
  let syncService: SyncServiceProtocol
  let playerLoaderService: PlayerLoaderService
  let preferencesService: PreferencesSyncServiceProtocol
  let externalProgressService: ExternalProgressRefreshing

  init(
    playerManager: PlayerManagerProtocol,
    syncService: SyncServiceProtocol,
    playerLoaderService: PlayerLoaderService,
    preferencesService: PreferencesSyncServiceProtocol,
    externalProgressService: ExternalProgressRefreshing
  ) {
    self.playerManager = playerManager
    self.syncService = syncService
    self.playerLoaderService = playerLoaderService
    self.preferencesService = preferencesService
    self.externalProgressService = externalProgressService
  }

  func syncList(at relativePath: String?) async throws {
    // Pref pull runs in parallel with content sync and is independent of the
    // item-sync queue state — kick it off first so a queue-blocked content
    // sync doesn't skip the pref refresh.
    async let prefPull: Void = { await preferencesService.pullFromServer(force: false) }()

    do {
      if let relativePath {
        try await syncService.syncListContents(at: relativePath)
      } else if UserDefaults.standard.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents) == true {
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
    // background context and the progress ingest writes on the view context, and with no
    // merge policy set the two must not overlap. Runs whatever the cloud outcome was — the
    // media servers are separate hosts, and the pull is gated on the entitlement inside.
    await externalProgressService.refreshItems(at: relativePath)

    _ = await prefPull
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
