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
    watchConnectivityService: WatchConnectivityService
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
  }

  func checkAndReloadIfSyncIsEnabled() {
    self.hasSyncEnabled = accountService.hasSyncEnabled()
  }

  func updateSyncEnabled(_ enabled: Bool) {
    hasSyncEnabled = enabled
    syncService.isActive = enabled
  }
  
  func updateConcurrentService(_ accessLevel: AccessLevel) {
    switch accessLevel {
    case .lite:
      concurrenceService.accessPolicy = [
        .update: true,
        .uploadFile: false,
      ]
    case .pro:
      concurrenceService.accessPolicy = [
        .update: true,
        .uploadFile: true,
      ]
    default:
      concurrenceService.accessPolicy = [
        .update: false,
        .uploadFile: false,
      ]
    }
  }
}
