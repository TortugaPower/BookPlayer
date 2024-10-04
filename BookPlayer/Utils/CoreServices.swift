//
//  CoreServices.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/4/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

struct CoreServices {
  let dataManager: DataManager
  let accountService: AccountService
  let syncService: SyncService
  let libraryService: LibraryService
  let playbackService: PlaybackService
  let playerManager: PlayerManager
  let playerLoaderService: PlayerLoaderService
  let watchService: PhoneWatchConnectivityService
}
