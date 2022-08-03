//
//  PlaybackService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/11/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

public protocol PlaybackServiceProtocol {
  func updatePlaybackTime(item: PlayableItem, time: Double)
  func getPlayableItem(before relativePath: String, parentFolder: String?) -> PlayableItem?
  func getPlayableItem(after relativePath: String, parentFolder: String?, autoplayed: Bool) -> PlayableItem?
  func getFirstPlayableItem(in folder: Folder, isUnfinished: Bool?) throws -> PlayableItem?
  func getPlayableItem(from item: LibraryItem) throws -> PlayableItem?
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
    self.libraryService.updatePlaybackTime(relativePath: item.relativePath, time: time, date: now)

    if let currentChapter = item.currentChapter,
       item.currentTime > currentChapter.end || item.currentTime < currentChapter.start {
      item.updateCurrentChapter()
    }
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

    if let folder = previousItem as? Folder,
       folder.type == .regular {
      return try? getFirstPlayableItem(
        in: folder,
        isUnfinished: nil
      )
    }

    return try? getPlayableItem(from: previousItem)
  }

  public func getPlayableItem(after relativePath: String, parentFolder: String?, autoplayed: Bool) -> PlayableItem? {
    guard
      let orderRank = self.libraryService.getItemProperty(
        #keyPath(LibraryItem.orderRank),
        relativePath: relativePath
      ) as? Int16
    else { return nil }

    guard
      let nextItem = self.libraryService.findFirstItem(
        in: parentFolder,
        afterRank: orderRank,
        isUnfinished: autoplayed == true
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
          autoplayed: autoplayed
        )
      }

      return nil
    }

    if let folder = nextItem as? Folder,
       folder.type == .regular {
      return try? getFirstPlayableItem(
        in: folder,
        isUnfinished: autoplayed == true
      )
    }

    return try? getPlayableItem(from: nextItem)
  }

  public func getFirstPlayableItem(in folder: Folder, isUnfinished: Bool?) throws -> PlayableItem? {
    let child = self.libraryService.findFirstItem(
      in: folder.relativePath,
      isUnfinished: isUnfinished
    )

    switch child {
    case let childFolder as Folder:
      if childFolder.type == .regular {
        return try getFirstPlayableItem(in: childFolder, isUnfinished: isUnfinished)
      } else {
        return try self.getPlayableItemFrom(folder: childFolder)
      }
    case let book as Book:
      return try self.getPlayableItemFrom(book: book)
    default:
      return nil
    }

  }

  public func getPlayableItem(from item: LibraryItem) throws -> PlayableItem? {
    switch item {
    case let folder as Folder:
      return try self.getPlayableItemFrom(folder: folder)
    case let book as Book:
      return try self.getPlayableItemFrom(book: book)
    default:
      throw BookPlayerError.runtimeError("Can't get a playable item for: \n\(String(describing: item.relativePath))")
    }
  }

  func getPlayableItemFrom(book: Book) throws -> PlayableItem {
    let chapters = try self.getPlayableChapters(from: book)

    return PlayableItem(
      title: book.title,
      author: book.details,
      chapters: chapters,
      currentTime: book.currentTime,
      duration: book.duration,
      relativePath: book.relativePath,
      parentFolder: book.folder?.relativePath,
      percentCompleted: book.percentCompleted,
      lastPlayDate: book.lastPlayDate,
      isFinished: book.isFinished,
      isBoundBook: false
    )
  }

  func getPlayableChapters(from book: Book) throws -> [PlayableChapter] {
    guard
      let chapters = self.libraryService.getChapters(from: book.relativePath)
    else {
      throw BookPlayerError.runtimeError(
        String.localizedStringWithFormat(
          "error_loading_chapters".localized,
          String(describing: book.relativePath!)
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
          index: Int16(index + 1)
        )
      })
  }

  func getPlayableItemFrom(folder: Folder) throws -> PlayableItem {
    let chapters = try self.getPlayableChapters(from: folder)

    var duration: TimeInterval?

    if let lastChapter = chapters.last {
      duration = lastChapter.start + lastChapter.duration
    }

    return PlayableItem(
      title: folder.title,
      author: chapters.first?.author ?? "voiceover_unknown_author".localized,
      chapters: chapters,
      currentTime: folder.currentTime,
      duration: duration ?? folder.duration,
      relativePath: folder.relativePath,
      parentFolder: folder.folder?.relativePath,
      percentCompleted: folder.percentCompleted,
      lastPlayDate: folder.lastPlayDate,
      isFinished: folder.isFinished,
      isBoundBook: true
    )
  }

  func getPlayableChapters(from folder: Folder) throws -> [PlayableChapter] {
    guard
      let items = self.libraryService.fetchContents(
        at: folder.relativePath,
        limit: nil,
        offset: nil
      ) as? [Book]
    else {
      throw BookPlayerError.runtimeError(
        String.localizedStringWithFormat(
          "error_loading_chapters".localized,
          String(describing: folder.relativePath!)
        )
      )
    }

    guard !items.isEmpty else {
      throw BookPlayerError.runtimeError(
        String.localizedStringWithFormat(
          "error_empty_chapters".localized,
          String(describing: folder.title!)
        )
      )
    }

    var currentDuration = 0.0

    return items.enumerated()
      .map({ (index, book) in
        let chapter = PlayableChapter(
          title: book.title,
          author: book.details,
          start: currentDuration,
          duration: book.duration,
          relativePath: book.relativePath,
          index: Int16(index + 1)
        )

        currentDuration += book.duration + 0.01 // possible fix for chapter threshold
        return chapter
      })
  }
}
