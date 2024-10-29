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
  let accountService: AccountServiceProtocol
  let syncService: SyncServiceProtocol
  let libraryService: LibraryService
  let playbackService: PlaybackServiceProtocol
  let playerManager: PlayerManagerProtocol
  let singleFileDownloadService: SingleFileDownloadService
  let playerLoaderService: PlayerLoaderService
  let watchService: PhoneWatchConnectivityService
}
