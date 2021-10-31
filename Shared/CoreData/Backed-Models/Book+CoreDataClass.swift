//
//  Book+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

@objc(Book)
public class Book: LibraryItem {
    var filename: String {
        return self.title + "." + self.ext
    }

    public var currentChapter: Chapter?

    // needed to invalide cache of folder
    override public func setCurrentTime(_ time: Double) {
        self.currentTime = time
        self.folder?.resetCachedProgress()
    }

    var displayTitle: String {
        return self.title
    }

    public override var progress: Double {
        guard self.duration > 0 else { return 0 }

        return self.currentTime
    }

    public override var progressPercentage: Double {
        guard self.duration > 0 else { return 0 }

        return self.currentTime / self.duration
    }

    public var percentage: Double {
        return round(self.progressPercentage * 100)
    }

    public var hasChapters: Bool {
        return !(self.chapters?.array.isEmpty ?? true)
    }

    public override func getItem(with relativePath: String) -> LibraryItem? {
        return self.relativePath == relativePath ? self : nil
    }

    public override func jumpToStart() {
        self.setCurrentTime(0.0)
    }

    public override func markAsFinished(_ flag: Bool) {
        self.isFinished = flag

        // To avoid progress display side-effects
        if !flag,
            self.currentTime.rounded(.up) == self.duration.rounded(.up) {
            self.setCurrentTime(0.0)
        }

        self.folder?.updateCompletionState()
    }

    public func currentTimeInContext(_ prefersChapterContext: Bool) -> TimeInterval {
        guard !self.isFault else {
            return 0.0
        }

        guard
            prefersChapterContext,
            self.hasChapters,
            let start = self.currentChapter?.start else {
            return self.currentTime
        }

        return self.currentTime - start
    }

    public func maxTimeInContext(_ prefersChapterContext: Bool, _ prefersRemainingTime: Bool) -> TimeInterval {
        guard !self.isFault else {
            return 0.0
        }

        guard
            prefersChapterContext,
            self.hasChapters,
            let duration = self.currentChapter?.duration else {
            let time = prefersRemainingTime
                ? self.currentTimeInContext(prefersChapterContext) - self.duration
                : self.duration
            return time
        }

        let time = prefersRemainingTime
            ? self.currentTimeInContext(prefersChapterContext) - duration
            : duration

        return time
    }

    public func durationTimeInContext(_ prefersChapterContext: Bool) -> TimeInterval {
        guard !self.isFault else {
            return 0.0
        }

        guard
            prefersChapterContext,
            self.hasChapters,
            let duration = self.currentChapter?.duration else {
            return self.duration
        }

        return duration
    }

    public override func awakeFromFetch() {
        super.awakeFromFetch()

        self.updateCurrentChapter()
    }

  public func updateCurrentChapter() {
    guard let chapter = self.getChapter(at: self.currentTime) else { return }

    self.currentChapter = chapter
  }

  public func updatePlayDate() {
    let now = Date()
    self.lastPlayDate = now

    guard let folder = self.folder else { return }

    folder.lastPlayDate = now
  }

  public override func getFolder(matching relativePath: String) -> Folder? {
    return self.folder?.getFolder(matching: relativePath)
  }

  public override func getBookToPlay() -> Book? {
    return self
  }

  public func hasChapter(after chapter: Chapter) -> Bool {
    return self.nextChapter(after: chapter) != nil
  }

  public func hasChapter(before chapter: Chapter) -> Bool {
    return self.previousChapter(before: chapter) != nil
  }

  public func nextChapter(after chapter: Chapter) -> Chapter? {
    guard let chapters = self.chapters?.array as? [Chapter],
          !chapters.isEmpty else {
            return nil
          }

    if chapter == chapters.last { return nil }

    return chapters[Int(chapter.index)]
  }

  public func previousChapter(before chapter: Chapter) -> Chapter? {
    guard let chapters = self.chapters?.array as? [Chapter],
          !chapters.isEmpty else {
            return nil
          }

    if chapter == chapters.first { return nil }

    return chapters[Int(chapter.index) - 2]
  }

  public func getChapter(at globalTime: Double) -> Chapter? {
    guard let chapters = self.chapters?.array as? [Chapter], !chapters.isEmpty else {
        return nil
    }

    return chapters.first { $0.start <= globalTime && $0.end >= globalTime }
  }

  public func previousBook() -> Book? {
    if
      let folder = self.folder,
      let previous = folder.getPreviousBook(before: self) {
      return previous
    }

    return self.getLibrary()?.getPreviousBook(before: self)
  }

  public func nextBook(autoplayed: Bool) -> Book? {
    if
      let folder = self.folder,
      let next = folder.getNextBook(after: self) {
      return next
    }

    if autoplayed {
      guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled.rawValue) else {
        return nil
      }
    }

    return self.getLibrary()?.getNextBook(after: self)
  }

    public func getInterval(from proposedInterval: TimeInterval) -> TimeInterval {
        let interval = proposedInterval > 0
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

    enum CodingKeys: String, CodingKey {
        case currentTime, duration, identifier, relativePath, percentCompleted, title, author, ext, folder, orderRank
    }

    public override func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(currentTime, forKey: .currentTime)
      try container.encode(duration, forKey: .duration)
      try container.encode(identifier, forKey: .identifier)
      try container.encode(relativePath, forKey: .relativePath)
      try container.encode(percentCompleted, forKey: .percentCompleted)
      try container.encode(title, forKey: .title)
      try container.encode(author, forKey: .author)
      try container.encode(ext, forKey: .ext)
      try container.encode(orderRank, forKey: .orderRank)
    }

    public required convenience init(from decoder: Decoder) throws {
        // Create NSEntityDescription with NSManagedObjectContext
        guard let contextUserInfoKey = CodingUserInfoKey.context,
            let managedObjectContext = decoder.userInfo[contextUserInfoKey] as? NSManagedObjectContext,
            let entity = NSEntityDescription.entity(forEntityName: "Book", in: managedObjectContext) else {
            fatalError("Failed to decode Book!")
        }
        self.init(entity: entity, insertInto: nil)

        let values = try decoder.container(keyedBy: CodingKeys.self)
        currentTime = try values.decode(Double.self, forKey: .currentTime)
        duration = try values.decode(Double.self, forKey: .duration)
        identifier = try values.decode(String.self, forKey: .identifier)
        relativePath = try values.decode(String.self, forKey: .relativePath)
        percentCompleted = try values.decode(Double.self, forKey: .percentCompleted)
        title = try values.decode(String.self, forKey: .title)
        author = try values.decode(String.self, forKey: .author)
        ext = try values.decode(String.self, forKey: .ext)
    }
}

extension CodingUserInfoKey {
    public static let context = CodingUserInfoKey(rawValue: "context")
}
