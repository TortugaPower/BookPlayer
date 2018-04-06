//
//  Book.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 04.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class Book: NSObject {
    var identifier: String {
        return self.fileURL.lastPathComponent
    }

    var duration: Int {
        return Int(CMTimeGetSeconds(self.asset.duration))
    }

    var displayTitle: String {
        return title + " - " + author
    }

    var title: String
    var author: String
    var artwork: UIImage
    var asset: AVAsset
    var fileURL: URL

    var chapters: [Chapter]?

    var currentChapter: Chapter? {
        return self.chapters?.first
    }

    var hasChapters: Bool {
        guard let isEmpty = self.chapters?.isEmpty else {
            return false
        }

        return !isEmpty
    }

    init(title: String, author: String, artwork: UIImage, asset: AVAsset, fileURL: URL) {
        self.title = title
        self.author = author
        self.artwork = artwork
        self.asset = asset
        self.fileURL = fileURL
    }

    func loadChapters() -> [Chapter] {
        let playerItem = AVPlayerItem(asset: self.asset)

        // try loading chapters
        var chapterIndex = 1
        var chapters = [Chapter]()

        for locale in playerItem.asset.availableChapterLocales {
            let chaptersMetadata = playerItem.asset.chapterMetadataGroups(withTitleLocale: locale, containingItemsWithCommonKeys: [AVMetadataKey.commonKeyArtwork])

            for chapterMetadata in chaptersMetadata {
                let chapter = Chapter(
                    title: AVMetadataItem.metadataItems(
                        from: chapterMetadata.items,
                        withKey: AVMetadataKey.commonKeyTitle,
                        keySpace: AVMetadataKeySpace.common
                    ).first?.value?.copy(with: nil) as? String ?? "Chapter \(chapterIndex)",
                    start: Int(CMTimeGetSeconds(chapterMetadata.timeRange.start)),
                    duration: Int(CMTimeGetSeconds(chapterMetadata.timeRange.duration)),
                    index: chapterIndex
                )

                chapters.append(chapter)

                chapterIndex += 1
            }
        }

        return chapters
    }
}

struct Chapter {
    var title: String
    var start: Int
    var duration: Int
    var index: Int
}
