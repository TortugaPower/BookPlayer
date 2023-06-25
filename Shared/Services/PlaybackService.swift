//
//  PlaybackService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/11/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

/// sourcery: AutoMockable
public protocol PlaybackServiceProtocol {
  func updatePlaybackTime(item: PlayableItem, time: Double)
  func getPlayableItem(before relativePath: String, parentFolder: String?) async -> PlayableItem?
  func getPlayableItem(
    after relativePath: String,
    parentFolder: String?,
    autoplayed: Bool,
    restartFinished: Bool
  ) async -> PlayableItem?
  func getFirstPlayableItem(in folder: SimpleLibraryItem, isUnfinished: Bool?) async throws -> PlayableItem?
  func getPlayableItem(from item: SimpleLibraryItem) async throws -> PlayableItem?
  func getNextChapter(from item: PlayableItem) -> PlayableChapter?
}

public final class PlaybackService: PlaybackServiceProtocol {
  let libraryService: LibraryServiceProtocol

  public init(libraryService: LibraryServiceProtocol) {
    self.libraryService = libraryService
  }

  public func updatePlaybackTime(item: PlayableItem, time: Double) {
    let now = Date()
    item.lastPlayDate = now
    item.currentTime = time
    item.percentCompleted = round((item.currentTime / item.duration) * 100)
    self.libraryService.updatePlaybackTime(relativePath: item.relativePath, time: time, date: now, scheduleSave: true)
  }

  public func getNextChapter(from item: PlayableItem) -> PlayableChapter? {
    if item.chapters.last == item.currentChapter {
      return nil
    } else {
      return item.nextChapter(after: item.currentChapter)
    }
  }

  public func getPlayableItem(before relativePath: String, parentFolder: String?) async -> PlayableItem? {
    guard
      let orderRank = libraryService.getItemProperty(
        #keyPath(LibraryItem.orderRank),
        relativePath: relativePath
      ) as? Int16
    else { return nil }

    guard
      let previousItem = await libraryService.findFirstItem(
        in: parentFolder,
        beforeRank: orderRank
      )
    else {
      if let parentFolderPath = parentFolder {
        let containerPathForParentFolder = libraryService.getItemProperty(
          #keyPath(LibraryItem.folder.relativePath),
          relativePath: parentFolderPath
        ) as? String
        return await getPlayableItem(
          before: parentFolderPath,
          parentFolder: containerPathForParentFolder
        )
      }

      return nil
    }

    if previousItem.type == .folder {
      return try? await getFirstPlayableItem(
        in: previousItem,
        isUnfinished: nil
      )
    }

    return try? await getPlayableItem(from: previousItem)
  }

  public func getPlayableItem(
    after relativePath: String,
    parentFolder: String?,
    autoplayed: Bool,
    restartFinished: Bool
  ) async -> PlayableItem? {
    guard
      let orderRank = libraryService.getItemProperty(
        #keyPath(LibraryItem.orderRank),
        relativePath: relativePath
      ) as? Int16
    else { return nil }

    var isUnfinished: Bool?

    if autoplayed == true,
       !restartFinished {
      isUnfinished = true
    }

    guard
      let nextItem = await libraryService.findFirstItem(
        in: parentFolder,
        afterRank: orderRank,
        isUnfinished: isUnfinished
      )
    else {
      if let parentFolderPath = parentFolder {
        let containerPathForParentFolder = libraryService.getItemProperty(
          #keyPath(LibraryItem.folder.relativePath),
          relativePath: parentFolderPath
        ) as? String
        return await getPlayableItem(
          after: parentFolderPath,
          parentFolder: containerPathForParentFolder,
          autoplayed: autoplayed,
          restartFinished: restartFinished
        )
      }

      return nil
    }

    if nextItem.type == .folder {
      return try? await getFirstPlayableItem(
        in: nextItem,
        isUnfinished: isUnfinished
      )
    }

    return try? await getPlayableItem(from: nextItem)
  }

  public func getFirstPlayableItem(in folder: SimpleLibraryItem, isUnfinished: Bool?) async throws -> PlayableItem? {
    guard let child = await libraryService.findFirstItem(
      in: folder.relativePath,
      isUnfinished: isUnfinished
    ) else { return nil }

    switch child.type {
    case .folder:
      return try await getFirstPlayableItem(in: child, isUnfinished: isUnfinished)
    case .bound:
      return try getPlayableItemFrom(folder: child)
    case .book:
      return try await getPlayableItemFrom(book: child)
    }

  }

  public func getPlayableItem(from item: SimpleLibraryItem) async throws -> PlayableItem? {
    switch item.type {
    case .folder, .bound:
      return try getPlayableItemFrom(folder: item)
    case .book:
      return try await getPlayableItemFrom(book: item)
    }
  }

  func getPlayableItemFrom(book: SimpleLibraryItem) async throws -> PlayableItem {
    let chapters = try await getPlayableChapters(book: book)

    return PlayableItem(
      title: book.title,
      author: book.details,
      chapters: chapters,
      currentTime: book.currentTime,
      duration: book.duration,
      relativePath: book.relativePath,
      parentFolder: book.parentFolder,
      percentCompleted: book.percentCompleted,
      lastPlayDate: book.lastPlayDate,
      isFinished: book.isFinished,
      isBoundBook: false
    )
  }

  func getPlayableChapters(book: SimpleLibraryItem) async throws -> [PlayableChapter] {
    guard
      let chapters = await libraryService.getChapters(from: book.relativePath)
    else {
      throw BookPlayerError.runtimeError(
        String.localizedStringWithFormat(
          "error_loading_chapters".localized,
          String(describing: book.relativePath)
        )
      )
    }

    guard !chapters.isEmpty else {
      return [
        PlayableChapter(
          title: book.title,
          author: book.details,
          start: 0.0,
          duration: book.duration,
          relativePath: book.relativePath,
          remoteURL: book.remoteURL,
          index: 1
        )
      ]
    }

    return chapters.enumerated()
      .map({ (index, chapter) in
        return PlayableChapter(
          title: chapter.title,
          author: book.details,
          start: chapter.start,
          duration: chapter.duration,
          relativePath: book.relativePath,
          remoteURL: book.remoteURL,
          index: Int16(index + 1)
        )
      })
  }

  func getPlayableItemFrom(folder: SimpleLibraryItem) throws -> PlayableItem {
    let chapters = try getPlayableChapters(folder: folder)

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
      author: chapters.first?.author ?? "voiceover_unknown_author".localized,
      chapters: chapters,
      currentTime: folder.currentTime,
      duration: duration ?? folder.duration,
      relativePath: folder.relativePath,
      parentFolder: folder.parentFolder,
      percentCompleted: percentCompleted,
      lastPlayDate: folder.lastPlayDate,
      isFinished: folder.isFinished,
      isBoundBook: true
    )
  }

  func getPlayableChapters(folder: SimpleLibraryItem) throws -> [PlayableChapter] {
    guard
      let items = libraryService.fetchContents(
        at: folder.relativePath,
        limit: nil,
        offset: nil
      )
    else {
      throw BookPlayerError.runtimeError(
        String.localizedStringWithFormat(
          "error_loading_chapters".localized,
          String(describing: folder.relativePath)
        )
      )
    }

    guard !items.isEmpty else {
      throw BookPlayerError.runtimeError(
        String.localizedStringWithFormat(
          "error_empty_chapters".localized,
          String(describing: folder.title)
        )
      )
    }

    var currentDuration = 0.0

    return items.enumerated()
      .map({ (index, book) in
        let truncatedDuration = TimeParser.truncateTime(book.duration)

        let chapter = PlayableChapter(
          title: book.title,
          author: book.details,
          start: currentDuration,
          duration: truncatedDuration,
          relativePath: book.relativePath,
          remoteURL: book.remoteURL,
          index: Int16(index + 1)
        )

        currentDuration = TimeParser.truncateTime(currentDuration + truncatedDuration)

        return chapter
      })
  }
}
