//
//  CoreServices.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/4/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

struct CoreServices {
  let accountService: AccountService
  let dataManager: DataManager
  let hardcoverService: HardcoverServiceProtocol
  let libraryService: LibraryService
  let playbackService: PlaybackServiceProtocol
  let playerLoaderService: PlayerLoaderService
  let playerManager: PlayerManagerProtocol
  let syncService: SyncService
  let watchService: PhoneWatchConnectivityService
}
