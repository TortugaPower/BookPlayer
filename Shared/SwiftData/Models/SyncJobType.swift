//
//  SyncJobType.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/9/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

public enum SyncJobType: String, CaseIterable, Codable {
  case upload
  case update
  case move
  case renameFolder
  case delete
  case shallowDelete
  case setBookmark
  case deleteBookmark
  case uploadArtwork
  case matchUuid
  case externalResource
  case externalResourceToDownload
  case deleteExternalResource
  /// Progress update pushed to an external provider (Jellyfin/AudiobookShelf/Hardcover)
  case externalUpdate
  /// File upload to the BookPlayer server storage
  case uploadFile
}

/// Queue keys for the tasks container. The `sync` queue serially runs the
/// BookPlayer-server jobs; every other key (provider names, `uploadFile`)
/// runs concurrently with the rest.
public enum TaskQueueKey {
  public static let sync = "sync"
  public static let uploadFile = "uploadFile"
}
