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

  /// Moves `items` into `folder`, or to the library root when it's nil. One whose name is taken
  /// there stays where it is: the rest move, then this throws the error a move onto a taken name
  /// throws (`LibraryService.nameTakenError`), for the first one that didn't.
  func move(_ items: [LibraryItemRef], into folder: LibraryItemRef?) throws {
    let outcome = try libraryService.moveItems(items, inside: folder?.relativePath)
    if !outcome.moved.isEmpty {
      syncService.scheduleMove(items: outcome.moved, to: folder)
    }

    if let clash = outcome.notMoved.first {
      throw LibraryService.nameTakenError(moving: clash.relativePath, into: folder?.relativePath)
    }
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
    // Into a new folder, so names only clash with a stray file there
    var outcome = MoveOutcome(moved: [], notMoved: [])
    if !items.isEmpty {
      outcome = try libraryService.moveItems(items, inside: folder.relativePath)
    }
    let moved = outcome.moved
    if !moved.isEmpty {
      syncService.scheduleMove(items: moved, to: LibraryItemRef(relativePath: folder.relativePath, uuid: folder.uuid))
    }
    try libraryService.updateFolder(at: folder.relativePath, type: type)
    libraryService.rebuildFolderDetails(folder.relativePath)

    if let currentRelativePath = playerManager.currentItem?.relativePath,
      moved.contains(where: { $0.relativePath == currentRelativePath })
    {
      playerManager.stop()
    }

    if let clash = outcome.notMoved.first {
      throw LibraryService.nameTakenError(moving: clash.relativePath, into: folder.relativePath)
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
