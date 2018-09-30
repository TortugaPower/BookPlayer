//
//  Book+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 9/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Book)
public class Book: LibraryItem {
    public var currentChapter: Chapter? {
        guard let chapters = self.chapters?.array as? [Chapter], !chapters.isEmpty else {
            return nil
        }

        for chapter in chapters where chapter.start <= self.currentTime && chapter.end > self.currentTime {
            return chapter
        }

        return nil
    }

    public var filename: String {
        return self.title + "." + self.ext
    }

    var displayTitle: String {
        return self.title
    }

    public var progress: Double {
        return self.currentTime / self.duration
    }

    public var percentage: Double {
        return round(self.progress * 100)
    }

    public var hasChapters: Bool {
        return !(self.chapters?.array.isEmpty ?? true)
    }

    // TODO: This is a makeshift version of a proper completion property.
    // See https://github.com/TortugaPower/BookPlayer/issues/201
    public var isCompleted: Bool {
        return round(self.currentTime) >= round(self.duration)
    }
}
