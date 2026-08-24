//
//  PlaybackService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/11/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

/// sourcery: AutoMockable
public protocol PlaybackServiceProtocol {
  func updatePlaybackTime(item: PlayableItem, time: Double)
  func getPlayableItem(before relativePath: String, parentFolder: String?) -> PlayableItem?
  func getPlayableItem(
    after relativePath: String,
    parentFolder: String?,
    autoplayed: Bool,
    restartFinished: Bool
  ) -> PlayableItem?
  func getFirstPlayableItem(in folder: SimpleLibraryItem, isUnfinished: Bool?) throws -> PlayableItem?
  func getPlayableItem(from item: SimpleLibraryItem) throws -> PlayableItem
  func getNextChapter(from item: PlayableItem, after chapter: PlayableChapter) -> PlayableChapter?
  /// Mark a folder path as stale when its progress calculation is deferred
  func markStaleProgress(folderPath: String)
  /// Process any deferred folder progress calculation
  /// - Returns: Boolean specifying if there were items to process or not
  func processFoldersStaleProgress() -> Bool
}

@Observable
public final class PlaybackService: PlaybackServiceProtocol {
  var libraryService: LibraryServiceProtocol!

  public init() {}

  public func setup(libraryService: LibraryServiceProtocol) {
    self.libraryService = libraryService
  }

  public func updatePlaybackTime(item: PlayableItem, time: Double) {
    let now = Date()
    item.lastPlayDate = now
    item.currentTime = time
    let progress = round((item.currentTime / item.duration) * 100)
    let percentCompleted =
      progress.isFinite
      ? progress
      : 0
    item.percentCompleted = percentCompleted
    self.libraryService.updatePlaybackTime(relativePath: item.relativePath, time: time, date: now, scheduleSave: true)
  }

  public func getNextChapter(from item: PlayableItem, after chapter: PlayableChapter) -> PlayableChapter? {
    guard !item.chapters.isEmpty else { return nil }

    if chapter == item.chapters.last { return nil }

    return item.chapters[Int(chapter.index)]
  }

  public func getPlayableItem(before relativePath: String, parentFolder: String?) -> PlayableItem? {
    /// Walk the parent's children in their EFFECTIVE (visible) order — the
    /// contract is "previous is whatever sits above this item in the list",
    /// under automatic sorts and Custom alike. Rank cursors can't express the
    /// Finder-style collation, so we index into the ordered sibling list
    /// (lightweight navigation entries — no full-row materialization).
    guard
      let siblings = self.libraryService.getOrderedSiblings(in: parentFolder),
      let currentIndex = siblings.firstIndex(where: { $0.relativePath == relativePath })
    else { return nil }

    guard currentIndex > 0 else {
      if let parentFolderPath = parentFolder {
        let containerPathForParentFolder =
          self.libraryService.getItemProperty(
            #keyPath(LibraryItem.folder.relativePath),
            relativePath: parentFolderPath
          ) as? String
        return getPlayableItem(
          before: parentFolderPath,
          parentFolder: containerPathForParentFolder
        )
      }

      return nil
    }

    return resolvePlayableItem(from: siblings[currentIndex - 1], isUnfinished: nil)
  }

  public func getPlayableItem(
    after relativePath: String,
    parentFolder: String?,
    autoplayed: Bool,
    restartFinished: Bool
  ) -> PlayableItem? {
    var isUnfinished: Bool?

    if autoplayed == true,
      !restartFinished
    {
      isUnfinished = true
    }

    /// Same visible-order walk as `getPlayableItem(before:)` — "next" is
    /// whatever sits below this item in the list. The unfinished filter (set
    /// only for autoplay without restart-finished) skips finished siblings,
    /// folders included, matching the old rank-cursor predicate.
    guard
      let siblings = self.libraryService.getOrderedSiblings(in: parentFolder),
      let currentIndex = siblings.firstIndex(where: { $0.relativePath == relativePath })
    else {
      /// Current item unknown here (deleted/moved mid-playback): stop, same
      /// as `getPlayableItem(before:)` — never hop out of a stale folder.
      return nil
    }

    let nextItem = siblings[siblings.index(after: currentIndex)...].first { candidate in
      isUnfinished == nil || !candidate.isFinished
    }

    guard let nextItem else {
      if let parentFolderPath = parentFolder {
        let containerPathForParentFolder =
          self.libraryService.getItemProperty(
            #keyPath(LibraryItem.folder.relativePath),
            relativePath: parentFolderPath
          ) as? String
        return getPlayableItem(
          after: parentFolderPath,
          parentFolder: containerPathForParentFolder,
          autoplayed: autoplayed,
          restartFinished: restartFinished
        )
      }

      return nil
    }

    return resolvePlayableItem(from: nextItem, isUnfinished: isUnfinished)
  }

  /// Materializes a navigation entry into a `PlayableItem`, descending into
  /// plain folders (matching the old cursor behavior: only `.folder` descends;
  /// `.bound` plays as a single unit).
  private func resolvePlayableItem(
    from entry: SimpleNavigationItem,
    isUnfinished: Bool?
  ) -> PlayableItem? {
    guard let item = self.libraryService.getSimpleItem(with: entry.relativePath) else { return nil }

    if item.type == .folder {
      return try? getFirstPlayableItem(
        in: item,
        isUnfinished: isUnfinished
      )
    }

    return try? getPlayableItem(from: item)
  }

  public func getFirstPlayableItem(in folder: SimpleLibraryItem, isUnfinished: Bool?) throws -> PlayableItem? {
    guard
      let child = self.libraryService.findFirstItem(
        in: folder.relativePath,
        isUnfinished: isUnfinished
      )
    else { return nil }

    switch child.type {
    case .folder:
      return try getFirstPlayableItem(in: child, isUnfinished: isUnfinished)
    case .bound:
      return try self.getPlayableItemFrom(folder: child)
    case .book:
      return try self.getPlayableItemFrom(book: child)
    }

  }

  public func getPlayableItem(from item: SimpleLibraryItem) throws -> PlayableItem {
    switch item.type {
    case .folder, .bound:
      return try self.getPlayableItemFrom(folder: item)
    case .book:
      return try self.getPlayableItemFrom(book: item)
    }
  }

  func getPlayableItemFrom(book: SimpleLibraryItem) throws -> PlayableItem {
    let chapters = try self.getPlayableChapters(book: book)

    return PlayableItem(
      title: book.title,
      author: book.details,
      chapters: chapters,
      currentTime: book.currentTime,
      duration: book.duration,
      relativePath: book.relativePath,
      uuid: book.uuid,
      parentFolder: book.parentFolder,
      percentCompleted: book.percentCompleted,
      lastPlayDate: book.lastPlayDate,
      isFinished: book.isFinished,
      isBoundBook: false
    )
  }

  func getPlayableChapters(book: SimpleLibraryItem) throws -> [PlayableChapter] {
    guard
      var chapters = self.libraryService.getChapters(from: book.relativePath)
    else {
      throw BookPlayerError.runtimeError(
        String.localizedStringWithFormat(
          "error_loading_chapters".localized,
          String(describing: book.relativePath)
        )
      )
    }

    /// Ignore chapters that don't have the duration set properly
    chapters = chapters.filter { $0.duration > 0 }

    // Resolve connection info once for the book
    var externalUrl: URL?
    var externalHeaders: [String: String] = [:]
    
    let externalResource = book.externalResources?.first(where: { $0.syncStatus != ExternalResource.SyncStatus.notSynced.rawValue })
    if let providerRaw = externalResource?.providerName,
       let provider = ExternalResource.ProviderName(rawValue: providerRaw) {
      
      let keychainService = KeychainService()
      let hostId = externalResource?.hostId ?? ""
      
      switch provider {
      case .jellyfin:
        let connections: [JellyfinConnectionData] = (try? keychainService.get(.jellyfinConnection)) ?? []
        // Resolved by stable host identity ONLY — no first-connection fallback. A resource whose
        // host doesn't match any saved server must surface as missing (connect-your-server), not
        // silently stream from whichever server happens to be configured (shared Android contract).
        let connection = IntegrationHostResolver.connection(for: hostId, in: connections)
        
        if let connection = connection, let externalResource = externalResource {
          let urlString = connection.buildDownloadUrl(providerId: externalResource.providerId)
          externalUrl = URL(string: urlString)
          // Custom headers first (reverse-proxy gates like Cloudflare Access), then the
          // integration's own Authorization so it always wins on conflict.
          // Case-insensitive dedup: a user-configured lowercase "authorization" must not
          // fight the integration's own header (same rule as JellyfinHeaderInjector).
          externalHeaders = connection.customHeaders.filter {
            $0.key.caseInsensitiveCompare("Authorization") != .orderedSame
          }
          externalHeaders["Authorization"] = "MediaBrowser Token=\"\(connection.accessToken)\""
        }
        
      case .audiobookshelf:
        let connections: [AudiobookShelfConnectionData] = (try? keychainService.get(.audiobookshelfConnection)) ?? []
        let connection = IntegrationHostResolver.connection(for: hostId, in: connections)
        
        if let connection = connection, let externalResource = externalResource {
          let urlString = connection.buildAudiobookshelfDownloadUrl(providerId: externalResource.providerId)
          externalUrl = URL(string: urlString)
          // Case-insensitive dedup: a user-configured lowercase "authorization" must not
          // fight the integration's own header (same rule as JellyfinHeaderInjector).
          externalHeaders = connection.customHeaders.filter {
            $0.key.caseInsensitiveCompare("Authorization") != .orderedSame
          }
          externalHeaders["Authorization"] = "Bearer \(connection.apiToken)"
        }
        
      default:
        break
      }
    }

    // If no chapters, create a single one using the book metadata
    guard !chapters.isEmpty else {
      return [
        PlayableChapter(
          title: book.title,
          author: book.details,
          start: 0.0,
          duration: book.duration,
          relativePath: book.relativePath,
          remoteURL: book.remoteURL,
          externalURL: externalUrl,
          index: 1,
          externalHeaders: externalHeaders
        )
      ]
    }

    // Map existing chapters and apply resolved connection info
    return chapters.enumerated()
      .map({ (index, chapter) in
        return PlayableChapter(
          title: chapter.title,
          author: book.details,
          start: chapter.start,
          duration: chapter.duration,
          relativePath: book.relativePath,
          remoteURL: book.remoteURL,
          externalURL: externalUrl,
          index: Int16(index + 1),
          externalHeaders: externalHeaders
        )
      })
  }

  func getPlayableItemFrom(folder: SimpleLibraryItem) throws -> PlayableItem {
    let chapters = try self.getPlayableChapters(folder: folder)

    var duration: TimeInterval?

    if let lastChapter = chapters.last {
      duration = lastChapter.start + lastChapter.duration
    }

    var percentCompleted = folder.percentCompleted

    if percentCompleted.isNaN || percentCompleted.isInfinite {
      percentCompleted = 0
    }

    return PlayableItem(
      title: folder.title,
      author: chapters.first?.author ?? folder.details,
      chapters: chapters,
      currentTime: folder.currentTime,
      duration: duration ?? folder.duration,
      relativePath: folder.relativePath,
      uuid: folder.uuid,
      parentFolder: folder.parentFolder,
      percentCompleted: percentCompleted,
      lastPlayDate: folder.lastPlayDate,
      isFinished: folder.isFinished,
      isBoundBook: true
    )
  }

  func getPlayableChapters(folder: SimpleLibraryItem) throws -> [PlayableChapter] {
    guard let items = self.libraryService.fetchContents(at: folder.relativePath, limit: nil, offset: nil) else {
      throw BookPlayerError.runtimeError(
        String.localizedStringWithFormat("error_loading_chapters".localized, String(describing: folder.relativePath))
      )
    }

    guard !items.isEmpty else {
      throw BookPlayerError.runtimeError(
        String.localizedStringWithFormat("error_empty_chapters".localized, String(describing: folder.title))
      )
    }

    var currentDuration = 0.0
    var index: Int16 = 0

    var chapters = [PlayableChapter]()
    for book in items {
      let nestedChapters = try getPlayableChapters(book: book)
      /// Nested chapters need to calculate the offset they'll use as a reference
      var localDuration: TimeInterval = 0
      var localCurrentDuration: TimeInterval = 0

      for nestedChapter in nestedChapters {
        let fileExtension = nestedChapter.fileURL.pathExtension

        /// If file is not audiovisual content, don't include it as part of the playback item
        if !fileExtension.isEmpty,
          let fileType = UTType(filenameExtension: fileExtension),
          !fileType.isSubtype(of: .audiovisualContent)
        {
          continue
        }

        let truncatedDuration = TimeParser.truncateTime(nestedChapter.duration)
        localDuration = truncatedDuration
        index += 1

        let chapter = PlayableChapter(
          title: nestedChapter.title,
          author: nestedChapter.author,
          start: currentDuration,
          duration: truncatedDuration,
          relativePath: nestedChapter.relativePath,
          remoteURL: nestedChapter.remoteURL,
          externalURL: nestedChapter.externalUrl,
          index: index,
          chapterOffset: nestedChapters.count == 1 ? 0 : localCurrentDuration,
          // Without the headers a streamed chapter inside a bound book hits the media
          // server unauthenticated and 401s.
          externalHeaders: nestedChapter.externalHeaders
        )
        currentDuration = TimeParser.truncateTime(currentDuration + truncatedDuration)
        localCurrentDuration = TimeParser.truncateTime(localCurrentDuration + localDuration)

        chapters.append(chapter)
      }
    }

    guard !chapters.isEmpty else {
      throw BookPlayerError.runtimeError(
        String.localizedStringWithFormat("error_empty_chapters".localized, String(describing: folder.title))
      )
    }

    return chapters
  }

  /// Mark a folder path as stale when its progress calculation is deferred
  public func markStaleProgress(folderPath: String) {
    let defaults = UserDefaults.standard

    var staleIdentifiers =
      defaults.stringArray(
        forKey: Constants.UserDefaults.staleProgressIdentifiers
      ) ?? []

    guard !staleIdentifiers.contains(folderPath) else { return }

    staleIdentifiers.append(folderPath)
    defaults.set(staleIdentifiers, forKey: Constants.UserDefaults.staleProgressIdentifiers)
  }

  /// Process any deferred folder progress calculation
  /// - Returns: Boolean specifying if there were items to process or not
  public func processFoldersStaleProgress() -> Bool {
    let defaults = UserDefaults.standard

    guard
      let staleIdentifiers = defaults.stringArray(
        forKey: Constants.UserDefaults.staleProgressIdentifiers
      ),
      !staleIdentifiers.isEmpty
    else { return false }

    for staleIdentifier in staleIdentifiers {
      libraryService.recursiveFolderProgressUpdate(from: staleIdentifier)
    }

    defaults.removeObject(forKey: Constants.UserDefaults.staleProgressIdentifiers)
    return true
  }
}
