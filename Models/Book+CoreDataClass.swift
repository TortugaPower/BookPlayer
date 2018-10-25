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

    enum CodingKeys: String, CodingKey {
        case currentTime, duration, identifier, percentCompleted, title, author, ext, usesDefaultArtwork, artworkColors, chapters, playlist
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentTime, forKey: .currentTime)
        try container.encode(duration, forKey: .duration)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(percentCompleted, forKey: .percentCompleted)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(ext, forKey: .ext)
        try container.encode(usesDefaultArtwork, forKey: .usesDefaultArtwork)
        try container.encode(artworkColors, forKey: .artworkColors)
        if let chaptersArray = self.chapters?.array as? [Chapter] {
            try container.encode(chaptersArray, forKey: .chapters)
        }
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
        percentCompleted = try values.decode(Double.self, forKey: .percentCompleted)
        title = try values.decode(String.self, forKey: .title)
        author = try values.decode(String.self, forKey: .author)
        ext = try values.decode(String.self, forKey: .ext)
        usesDefaultArtwork = try values.decode(Bool.self, forKey: .usesDefaultArtwork)
        artworkColors = try values.decode(ArtworkColors.self, forKey: .artworkColors)
        let chaptersArray = try values.decode(Array<Chapter>.self, forKey: .chapters)
        chapters = NSOrderedSet(array: chaptersArray)
    }
}

extension CodingUserInfoKey {
    public static let context = CodingUserInfoKey(rawValue: "context")
}
