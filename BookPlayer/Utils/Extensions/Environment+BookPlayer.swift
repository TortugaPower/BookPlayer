//
//  Environment+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

extension EnvironmentValues {
  @Entry var libraryService: LibraryService = .init()
  @Entry var accountService: AccountService = .init()
  @Entry var syncService: SyncService = .init()
  @Entry var playerLoaderService: PlayerLoaderService = .init()
  @Entry var playbackService: PlaybackService = .init()
  @Entry var syncQueueService: SyncQueueService = .init()
  /// The continued background upload task (placeholder: offers nothing until injected)
  @Entry var uploadContinuation: UploadContinuationController = .init()
  @Entry var jellyfinService: JellyfinConnectionService = .init()
  @Entry var audiobookshelfService: AudiobookShelfConnectionService = .init()
  /// Closes the whole media-server flow: Media Servers and the server browser on top of it. Set
  /// by whoever presents Media Servers (the library's sheet, an item's details), so the browser's
  /// Close, and the close after a confirmed import, end the flow they belong to.
  @Entry var closeMediaServers = CloseMediaServersAction {}
  @Entry var hardcoverService: HardcoverService = .init()
  @Entry var loadingState: LoadingOverlayState = .init()
  @Entry var playerState: PlayerState = .init()
  @Entry var passkeyService: PasskeyServiceProtocol = PasskeyService()
  /// Sticky-sort prefs service. The default is a placeholder shell; the real
  /// instance is injected by `MainCoordinator` after `AppServices` calls
  /// `setup(...)` on it.
  @Entry var preferencesService: PreferencesSyncService = .init()
}

extension EnvironmentValues {
  @Entry var listState: ListStateManager = .init()
  /// Cached path for containing folder of playing item in relation to a list path
  @Entry var playingItemParentPath: String?
  @Entry var libraryNode: LibraryNode?
  @Entry var importOperationState: ImportOperationState = .init()
  /// Dynamic bottom inset calculated from the actual mini player height
  @Entry var miniPlayerBottomInset: CGFloat = 80
  /// Actual tab bar content height read from UIKit (excludes device safe area)
  @Entry var tabBarContentHeight: CGFloat = 49
}

/// Called like SwiftUI's `DismissAction`: `closeMediaServers()`
struct CloseMediaServersAction {
  let action: () -> Void

  func callAsFunction() {
    action()
  }
}
