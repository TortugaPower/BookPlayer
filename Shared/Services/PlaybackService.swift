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
    item.currentTime = time
    item.percentCompleted = round((item.currentTime / item.duration) * 100)
    self.libraryService.updatePlaybackTime(relativePath: item.relativePath, time: time)

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
    let chapters = self.getPlayableChapters(from: book)

    if chapters.isEmpty {
      throw BookPlayerError.runtimeError(
        """
        Chapters couldn't be loaded.
        Debug information:
        \(String(describing: book.relativePath!))
        Chapters in DB: \(String(describing: book.chapters?.array.count))
        """
      )
    }

    return PlayableItem(
      title: book.title,
      author: book.author,
      chapters: chapters,
      currentTime: book.currentTime,
      duration: book.duration,
      relativePath: book.relativePath,
      percentCompleted: book.percentCompleted,
      isFinished: book.isFinished,
      useChapterTimeContext: false
    )
  }

  func getPlayableChapters(from book: Book) -> [PlayableChapter] {
    guard let chapters = book.chapters?.array as? [Chapter],
          !chapters.isEmpty else {
      return [PlayableChapter(title: book.title,
                              author: book.author,
                              start: 0.0,
                              duration: book.duration,
                              relativePath: book.relativePath,
                              index: 1)]
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
    let chapters = self.getPlayableChapters(from: folder)

    if chapters.isEmpty {
      throw BookPlayerError.runtimeError(
        """
        Chapters couldn't be loaded.
        Debug information:
        \(String(describing: folder.relativePath!))
        Volume: \(folder.type == .bound)
        Items in folder: \(String(describing: folder.items?.array.count))
        """
      )
    }

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
      isFinished: folder.isFinished,
      useChapterTimeContext: true
    )
  }

  func getPlayableChapters(from folder: Folder) -> [PlayableChapter] {
    guard let items = folder.items?.array as? [Book] else { return [] }

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
