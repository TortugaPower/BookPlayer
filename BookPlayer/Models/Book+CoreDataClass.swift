//
//  Book+CoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/14/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import AVFoundation
import CoreData
import Foundation

public class Book: LibraryItem {
    var fileURL: URL {
        return DataManager.getProcessedFolderURL().appendingPathComponent(identifier)
    }

    var filename: String {
        return title + "." + ext
    }

    var currentChapter: Chapter? {
        guard let chapters = self.chapters?.array as? [Chapter], !chapters.isEmpty else {
            return nil
        }

        for chapter in chapters where chapter.start <= currentTime && chapter.end > currentTime {
            return chapter
        }

        return nil
    }

    var displayTitle: String {
        return title
    }

    var progress: Double {
        return currentTime / duration
    }

    var percentage: Double {
        return round(progress * 100)
    }

    var hasChapters: Bool {
        return !(self.chapters?.array.isEmpty ?? true)
    }

    // TODO: This is a makeshift version of a proper completion property.
    // See https://github.com/TortugaPower/BookPlayer/issues/201
    override var isCompleted: Bool {
        return Int(round(currentTime)) == Int(round(duration))
    }

    func setChapters(from asset: AVAsset, context: NSManagedObjectContext) {
        for locale in asset.availableChapterLocales {
            let chaptersMetadata = asset.chapterMetadataGroups(withTitleLocale: locale, containingItemsWithCommonKeys: [AVMetadataKey.commonKeyArtwork])

            for (index, chapterMetadata) in chaptersMetadata.enumerated() {
                let chapterIndex = index + 1
                let chapter = Chapter(from: asset, context: context)

                chapter.title = AVMetadataItem.metadataItems(
                    from: chapterMetadata.items,
                    withKey: AVMetadataKey.commonKeyTitle,
                    keySpace: AVMetadataKeySpace.common
                ).first?.value?.copy(with: nil) as? String ?? ""
                chapter.start = CMTimeGetSeconds(chapterMetadata.timeRange.start)
                chapter.duration = CMTimeGetSeconds(chapterMetadata.timeRange.duration)
                chapter.index = Int16(chapterIndex)

                addToChapters(chapter)
            }
        }
    }

    convenience init(from bookUrl: FileItem, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Book", in: context)!
        self.init(entity: entity, insertInto: context)
        let fileURL = bookUrl.processedUrl!
        ext = fileURL.pathExtension
        identifier = fileURL.lastPathComponent
        let asset = AVAsset(url: fileURL)

        let titleFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String
        let authorFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String

        title = titleFromMeta ?? bookUrl.originalUrl.lastPathComponent.replacingOccurrences(of: "_", with: " ")
        author = authorFromMeta ?? "Unknown Author"
        duration = CMTimeGetSeconds(asset.duration)
        originalFileName = bookUrl.originalUrl.lastPathComponent

        var colors: ArtworkColors!
        if let data = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? NSData {
            artworkData = data
            colors = ArtworkColors(from: artwork, context: context)
        } else {
            colors = ArtworkColors(context: context)
            usesDefaultArtwork = true
        }

        artworkColors = colors

        setChapters(from: asset, context: context)

        let legacyIdentifier = bookUrl.originalUrl.lastPathComponent
        let storedTime = UserDefaults.standard.double(forKey: legacyIdentifier)

        // migration of time
        if storedTime > 0 {
            currentTime = storedTime
            UserDefaults.standard.removeObject(forKey: legacyIdentifier)
        }
    }

    override func getBookToPlay() -> Book? {
        return self
    }

    func nextBook() -> Book? {
        if
            let playlist = self.playlist,
            let next = playlist.getNextBook(after: self) {
            return next
        }

        guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled.rawValue) else {
            return nil
        }

        let item = playlist ?? self

        guard let nextItem = item.library?.getNextItem(after: item) else { return nil }

        if let book = nextItem as? Book {
            return book
        } else if let playlist = nextItem as? Playlist, let book = playlist.books?.firstObject as? Book {
            return book
        }

        return nil
    }
}
