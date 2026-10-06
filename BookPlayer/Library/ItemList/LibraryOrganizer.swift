//
//  LibraryOrganizer.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

/// Moves library items, wraps them in a new folder or volume, and turns folders into volumes
/// and back, with the matching sync tasks. What the list's multi-select actions and the import's
/// placement prompt share, so the two can't drift apart.
@MainActor
struct LibraryOrganizer {
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol
  let playerManager: PlayerManagerProtocol

  /// Moves `items` into `folder`, or to the library root when it's nil.
  func move(_ items: [LibraryItemRef], into folder: LibraryItemRef?) throws {
    try libraryService.moveItems(items, inside: folder?.relativePath)
    syncService.scheduleMove(items: items, to: folder)
  }

  /// Creates a folder (or a volume, by `type`) titled `title` inside `parentPath` (the library
  /// root when nil) and moves `items` into it. Playback stops when one of them is playing: its
  /// path changes under the player.
  ///
  /// - Returns: the new folder, or nil when `title` is blank and nothing was created.
  @discardableResult
  func createFolder(
    titled title: String,
    inside parentPath: String?,
    holding items: [LibraryItemRef],
    type: SimpleItemType
  ) async throws -> SimpleLibraryItem? {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return nil }

    let folder = try libraryService.createFolder(with: trimmedTitle, inside: parentPath)
    await syncService.scheduleUpload(items: [folder])
    if !items.isEmpty {
      try libraryService.moveItems(items, inside: folder.relativePath)
      syncService.scheduleMove(items: items, to: LibraryItemRef(relativePath: folder.relativePath, uuid: folder.uuid))
    }
    try libraryService.updateFolder(at: folder.relativePath, type: type)
    libraryService.rebuildFolderDetails(folder.relativePath)

    if let currentRelativePath = playerManager.currentItem?.relativePath,
      items.contains(where: { $0.relativePath == currentRelativePath })
    {
      playerManager.stop()
    }

    return folder
  }

  /// Turns `folders` into `type` (a volume, or a plain folder again). Playback stops when it's
  /// inside one of them.
  func convert(_ folders: [SimpleLibraryItem], to type: SimpleItemType) throws {
    for folder in folders {
      try libraryService.updateFolder(at: folder.relativePath, type: type)

      if let currentItem = playerManager.currentItem,
        currentItem.relativePath.contains(folder.relativePath)
      {
        playerManager.stop()
      }
    }
  }
}
