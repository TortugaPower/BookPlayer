//
//  CoreServices.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 19/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import Foundation

class CoreServices: ObservableObject {
  let dataManager: DataManager
  let accountService: AccountServiceProtocol
  var syncService: SyncServiceProtocol
  var concurrenceService: ConcurrenceServiceProtocol
  let libraryService: LibraryService
  let playbackService: PlaybackServiceProtocol
  let playerManager: PlayerManager
  let playerLoaderService: PlayerLoaderService
  let watchConnectivityService: WatchConnectivityService
  /// Pull-only on watchOS: resolves the sticky library sort so the list and
  /// playback navigation match the phone. Nothing on the watch writes sort
  /// preferences, and its pull is gated on the account's sync entitlement.
  let preferencesService: PreferencesSyncServiceProtocol

  @Published var hasSyncEnabled = false

  init(
    dataManager: DataManager,
    accountService: AccountServiceProtocol,
    syncService: SyncServiceProtocol,
    concurrenceService: ConcurrenceServiceProtocol,
    libraryService: LibraryService,
    playbackService: PlaybackServiceProtocol,
    playerManager: PlayerManager,
    playerLoaderService: PlayerLoaderService,
    watchConnectivityService: WatchConnectivityService,
    preferencesService: PreferencesSyncServiceProtocol
  ) {
    self.dataManager = dataManager
    self.accountService = accountService
    self.syncService = syncService
    self.concurrenceService = concurrenceService
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.hasSyncEnabled = accountService.hasSyncEnabled()
    self.playerManager = playerManager
    self.playerLoaderService = playerLoaderService
    self.watchConnectivityService = watchConnectivityService
    self.preferencesService = preferencesService
  }

  func checkAndReloadIfSyncIsEnabled() {
    self.hasSyncEnabled = accountService.hasSyncEnabled()
    // ConcurrenceService re-derives its own policy from .accountUpdate (posted by the
    // Shared AccountService update this flow just ran) — no manual forwarding needed.
  }

  func updateSyncEnabled(_ enabled: Bool) {
    hasSyncEnabled = enabled
    syncService.updateSyncEnabled(enabled)
  }

}
