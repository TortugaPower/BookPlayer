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
  func getPlayableItem(before relativePath: String, parentFolder: String?) -> PlayableItem?
  func getPlayableItem(
    after relativePath: String,
    parentFolder: String?,
    autoplayed: Bool,
    restartFinished: Bool
  ) -> PlayableItem?
  func getFirstPlayableItem(in folder: SimpleLibraryItem, isUnfinished: Bool?) throws -> PlayableItem?
  func getPlayableItem(from item: SimpleLibraryItem) throws -> PlayableItem?
  func getNextChapter(from item: PlayableItem, after chapter: PlayableChapter) -> PlayableChapter?
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

  public func getNextChapter(from item: PlayableItem, after chapter: PlayableChapter) -> PlayableChapter? {
    guard !item.chapters.isEmpty else { return nil }

    if chapter == item.chapters.last { return nil }

    return item.chapters[Int(chapter.index)]
  }

  public func getPlayableItem(before relativePath: String, parentFolder: String?) -> PlayableItem? {
    guard
      let orderRank = self.libraryService.getItemProperty(
        #keyPath(LibraryItem.orderRank),
        relativePath: relativePath
      ) as? Int16
    else { return nil }

    guard
      let previousItem = self.libraryService.findFirstItem(
        in: parentFolder,
        beforeRank: orderRank
      )
    else {
      if let parentFolderPath = parentFolder {
        let containerPathForParentFolder = self.libraryService.getItemProperty(
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

    if previousItem.type == .folder {
      return try? getFirstPlayableItem(
        in: previousItem,
        isUnfinished: nil
      )
    }

    return try? getPlayableItem(from: previousItem)
  }

  public func getPlayableItem(
    after relativePath: String,
    parentFolder: String?,
    autoplayed: Bool,
    restartFinished: Bool
  ) -> PlayableItem? {
    guard
      let orderRank = self.libraryService.getItemProperty(
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
      let nextItem = self.libraryService.findFirstItem(
        in: parentFolder,
        afterRank: orderRank,
        isUnfinished: isUnfinished
      )
    else {
      if let parentFolderPath = parentFolder {
        let containerPathForParentFolder = self.libraryService.getItemProperty(
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

    if nextItem.type == .folder {
      return try? getFirstPlayableItem(
        in: nextItem,
        isUnfinished: isUnfinished
      )
    }

    return try? getPlayableItem(from: nextItem)
  }

  public func getFirstPlayableItem(in folder: SimpleLibraryItem, isUnfinished: Bool?) throws -> PlayableItem? {
    guard let child = self.libraryService.findFirstItem(
      in: folder.relativePath,
      isUnfinished: isUnfinished
    ) else { return nil }

    switch child.type {
    case .folder:
      return try getFirstPlayableItem(in: child, isUnfinished: isUnfinished)
    case .bound:
      return try self.getPlayableItemFrom(folder: child)
    case .book:
      return try self.getPlayableItemFrom(book: child)
    }

  }

  public func getPlayableItem(from item: SimpleLibraryItem) throws -> PlayableItem? {
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
      parentFolder: book.parentFolder,
      percentCompleted: book.percentCompleted,
      lastPlayDate: book.lastPlayDate,
      isFinished: book.isFinished,
      isBoundBook: false
    )
  }

  func getPlayableChapters(book: SimpleLibraryItem) throws -> [PlayableChapter] {
    guard
      let chapters = self.libraryService.getChapters(from: book.relativePath)
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
      let items = self.libraryService.fetchContents(
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
