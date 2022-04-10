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
  func getPlayableItem(before relativePath: String) -> PlayableItem?
  func getPlayableItem(after relativePath: String, autoplayed: Bool) -> PlayableItem?
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

  public func getPlayableItem(before relativePath: String) -> PlayableItem? {
    let item = self.libraryService.getItem(with: relativePath)

    switch item {
    case let book as Book:
      guard let previousBook = book.previousBook() else { return nil }

      return try? self.getPlayableItem(from: previousBook)
    case let folder as Folder:
      guard let previousItem = folder.getLibrary()?.getPreviousBook(before: folder.relativePath) else { return nil }

      return try? self.getPlayableItem(from: previousItem)
    default:
      return nil
    }
  }

  public func getPlayableItem(after relativePath: String, autoplayed: Bool) -> PlayableItem? {
    let item = self.libraryService.getItem(with: relativePath)

    switch item {
    case let book as Book:
      guard let nextBook = book.nextBook(autoplayed: autoplayed) else { return nil }

      return try? self.getPlayableItem(from: nextBook)
    case let folder as Folder:
      guard let nextItem = folder.getLibrary()?.getNextBook(after: folder.relativePath) else { return nil }

      return try? self.getPlayableItem(from: nextItem)
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
      author: book.author,
      chapters: chapters,
      currentTime: book.currentTime,
      duration: book.duration,
      relativePath: book.relativePath,
      percentCompleted: book.percentCompleted,
      lastPlayDate: book.lastPlayDate,
      isFinished: book.isFinished,
      useChapterTimeContext: false
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
          author: book.author,
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
          author: book.author,
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
      percentCompleted: folder.percentCompleted,
      lastPlayDate: folder.lastPlayDate,
      isFinished: folder.isFinished,
      useChapterTimeContext: true
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
          author: book.author,
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
