//
//  PlayableItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/11/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Combine
import Foundation

public final class PlayableItem: NSObject, Identifiable {
  public var id: String {
    return relativePath
  }
  public let title: String
  public let author: String
  public let chapters: [PlayableChapter]
  public var currentTime: TimeInterval
  public let duration: TimeInterval
  @objc dynamic public let relativePath: String
  public let parentFolder: String?
  @objc dynamic public var percentCompleted: Double
  @objc dynamic public var lastPlayDate: Date?
  public var isFinished: Bool
  // This property is explicitly set for bound books, for seeking purposes
  public let isBoundBook: Bool

  @Published public var currentChapter: PlayableChapter!

  public var progressPercentage: Double {
    guard self.duration > 0 else { return 0 }

    return self.currentTime / self.duration
  }

  public var fileURL: URL {
    return DataManager.getProcessedFolderURL().appendingPathComponent(self.relativePath)
  }

  public lazy var filename: String = {
    fileURL.lastPathComponent
  }()

  enum CodingKeys: String, CodingKey {
    case title, author, chapters, currentTime, duration,
      relativePath, parentFolder, percentCompleted, lastPlayDate, isFinished, isBoundBook
  }

  public init(
    title: String,
    author: String,
    chapters: [PlayableChapter],
    currentTime: TimeInterval,
    duration: TimeInterval,
    relativePath: String,
    parentFolder: String?,
    percentCompleted: Double,
    lastPlayDate: Date?,
    isFinished: Bool,
    isBoundBook: Bool
  ) {
    self.title = title
    self.author = author
    self.chapters = chapters
    self.currentTime = currentTime
    self.duration = duration
    self.relativePath = relativePath
    self.parentFolder = parentFolder
    self.percentCompleted = percentCompleted
    self.lastPlayDate = lastPlayDate
    self.isFinished = isFinished
    self.isBoundBook = isBoundBook

    super.init()

    self.currentChapter = self.getChapter(at: self.currentTime) ?? chapters[0]
  }

  public func getChapterTime(in chapter: PlayableChapter, for globalTime: TimeInterval) -> TimeInterval {
    return globalTime - chapter.start + chapter.chapterOffset
  }

  public func getChapter(at globalTime: Double) -> PlayableChapter? {
    if let lastChapter = chapters.last,
      lastChapter.end == globalTime
    {
      return lastChapter
    }

    return self.chapters.first { globalTime < $0.end && $0.start <= globalTime }
  }

  public func currentTimeInContext(_ prefersChapterContext: Bool) -> TimeInterval {
    return prefersChapterContext
      ? self.currentTime - self.currentChapter.start
      : self.currentTime
  }

  public func maxTimeInContext(
    prefersChapterContext: Bool,
    prefersRemainingTime: Bool,
    at speedRate: Float
  ) -> TimeInterval {
    guard prefersChapterContext else {
      if prefersRemainingTime {
        let time = self.currentTimeInContext(prefersChapterContext) - self.duration
        return time / Double(speedRate)
      } else {
        return self.duration
      }
    }

    if prefersRemainingTime {
      let time = self.currentTimeInContext(prefersChapterContext) - self.currentChapter.duration
      return time / Double(speedRate)
    } else {
      return self.currentChapter.duration
    }
  }

  public func durationTimeInContext(_ prefersChapterContext: Bool) -> TimeInterval {
    return prefersChapterContext
      ? self.currentChapter.duration
      : self.duration
  }

  public func getInterval(from proposedInterval: TimeInterval) -> TimeInterval {
    let interval =
      proposedInterval > 0
      ? self.getForwardInterval(from: proposedInterval)
      : self.getRewindInterval(from: proposedInterval)

    return interval
  }

  private func getRewindInterval(from proposedInterval: TimeInterval) -> TimeInterval {
    guard let chapter = self.currentChapter else { return proposedInterval }

    if self.currentTime + proposedInterval > chapter.start {
      return proposedInterval
    }

    let chapterThreshold: TimeInterval = 3

    if chapter.start + chapterThreshold > currentTime {
      return proposedInterval
    }

    return -(self.currentTime - chapter.start)
  }

  private func getForwardInterval(from proposedInterval: TimeInterval) -> TimeInterval {
    guard let chapter = self.currentChapter else { return proposedInterval }

    if self.currentTime + proposedInterval < chapter.end {
      return proposedInterval
    }

    if chapter.end < currentTime {
      return proposedInterval
    }

    return chapter.end - self.currentTime + 0.01
  }

  public func hasChapter(after chapter: PlayableChapter) -> Bool {
    return self.nextChapter(after: chapter) != nil
  }

  public func hasChapter(before chapter: PlayableChapter) -> Bool {
    return self.previousChapter(before: chapter) != nil
  }

  public func nextChapter(after chapter: PlayableChapter) -> PlayableChapter? {
    guard !self.chapters.isEmpty else {
      return nil
    }

    if chapter == self.chapters.last { return nil }

    return self.chapters[Int(chapter.index)]
  }

  public func previousChapter(before chapter: PlayableChapter) -> PlayableChapter? {
    guard !self.chapters.isEmpty else {
      return nil
    }

    if chapter == self.chapters.first { return nil }

    return self.chapters[Int(chapter.index) - 2]
  }
}

extension PlayableItem: Codable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.title, forKey: .title)
    try container.encode(self.author, forKey: .author)
    try container.encode(self.chapters, forKey: .chapters)
    try container.encode(self.currentTime, forKey: .currentTime)
    try container.encode(self.duration, forKey: .duration)
    try container.encode(self.relativePath, forKey: .relativePath)
    try? container.encode(self.parentFolder, forKey: .parentFolder)
    try container.encode(self.percentCompleted, forKey: .percentCompleted)
    try? container.encode(self.lastPlayDate, forKey: .lastPlayDate)
    try container.encode(self.isFinished, forKey: .isFinished)
    try container.encode(self.isBoundBook, forKey: .isBoundBook)
  }

  public convenience init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      title: try values.decode(String.self, forKey: .title),
      author: try values.decode(String.self, forKey: .author),
      chapters: try values.decode([PlayableChapter].self, forKey: .chapters),
      currentTime: try values.decode(TimeInterval.self, forKey: .currentTime),
      duration: try values.decode(TimeInterval.self, forKey: .duration),
      relativePath: try values.decode(String.self, forKey: .relativePath),
      parentFolder: try? values.decode(String?.self, forKey: .parentFolder),
      percentCompleted: try values.decode(Double.self, forKey: .percentCompleted),
      lastPlayDate: try? values.decode(Date.self, forKey: .lastPlayDate),
      isFinished: try values.decode(Bool.self, forKey: .isFinished),
      isBoundBook: try values.decode(Bool.self, forKey: .isBoundBook)
    )
  }
}
