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
    public var fileURL: URL? {
        guard self.identifier != nil else { return nil }

        return DataManager.getProcessedFolderURL().appendingPathComponent(self.identifier)
    }

    var filename: String {
        return self.title + "." + self.ext
    }

    public var currentChapter: Chapter?

    var displayTitle: String {
        return self.title
    }

    public override var progress: Double {
        guard self.duration > 0 else { return 0 }

        return self.currentTime / self.duration
    }

    public var percentage: Double {
        return round(self.progress * 100)
    }

    public var hasChapters: Bool {
        return !(self.chapters?.array.isEmpty ?? true)
    }

    public override func jumpToStart() {
        self.currentTime = 0.0
    }

    public override func markAsFinished(_ flag: Bool) {
        self.isFinished = flag

        // To avoid progress display side-effects
        if !flag,
            self.currentTime.rounded(.up) == self.duration.rounded(.up) {
            self.currentTime = 0.0
        }

        self.playlist?.updateCompletionState()
    }

    public override func awakeFromFetch() {
        super.awakeFromFetch()

        self.updateCurrentChapter()
    }

    public func updateCurrentChapter() {
        guard let chapters = self.chapters?.array as? [Chapter], !chapters.isEmpty else {
            return
        }

        guard let currentChapter = (chapters.first { (chapter) -> Bool in
            chapter.start <= self.currentTime && chapter.end > self.currentTime
        }) else { return }

        self.currentChapter = currentChapter
    }

    public override func getBookToPlay() -> Book? {
        return self
    }

    public func nextBook() -> Book? {
        if
            let playlist = self.playlist,
            let next = playlist.getNextBook(after: self) {
            return next
        }

        guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled.rawValue) else {
            return nil
        }

        let item = self.playlist ?? self

        guard let nextItem = item.library?.getNextItem(after: item) else { return nil }

        if let book = nextItem as? Book {
            return book
        } else if let playlist = nextItem as? Playlist, let book = playlist.books?.firstObject as? Book {
            return book
        }

        return nil
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
}
