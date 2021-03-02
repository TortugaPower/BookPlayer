//
//  Book+AVFoundation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import CoreData
import Foundation

extension Book {
    func setChapters(from asset: AVAsset, context: NSManagedObjectContext) {
        for locale in asset.availableChapterLocales {
            let chaptersMetadata = asset.chapterMetadataGroups(withTitleLocale: locale, containingItemsWithCommonKeys: [AVMetadataKey.commonKeyArtwork])

            for (index, chapterMetadata) in chaptersMetadata.enumerated() {
                let chapterIndex = index + 1
                let chapter = Chapter(from: asset, context: context)

                chapter.title = AVMetadataItem.metadataItems(from: chapterMetadata.items,
                                                             withKey: AVMetadataKey.commonKeyTitle,
                                                             keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String ?? ""
                chapter.start = CMTimeGetSeconds(chapterMetadata.timeRange.start)
                chapter.duration = CMTimeGetSeconds(chapterMetadata.timeRange.duration)
                chapter.index = Int16(chapterIndex)

                self.addToChapters(chapter)
            }
        }

        self.currentChapter = self.chapters?.array.first as? Chapter
    }

    public override func awakeFromFetch() {
        super.awakeFromFetch()

        // cleanup bug BKPLY-37
        if !self.usesDefaultArtwork,
           self.artworkData == nil,
           let fileURL = self.fileURL {
            self.usesDefaultArtwork = true
            let asset = AVAsset(url: fileURL)

            if fileURL.pathExtension == "mp3" {
                self.loadMp3Data(from: asset)
            } else if let data = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? NSData {
                self.artworkData = data
                self.usesDefaultArtwork = false
            }
        }

        self.updateCurrentChapter()
    }

    private func loadMp3Data(from asset: AVAsset) {
        for item in asset.metadata {
            guard let key = item.commonKey?.rawValue,
                  let value = item.value else { continue }

            switch key {
            case "title":
                self.title = value as? String
            case "artist":
                if self.author == "voiceover_unknown_author".localized {
                    self.author = value as? String
                }
            case "artwork" where value is NSData:
                self.artworkData = value as? NSData
                self.usesDefaultArtwork = false
            default:
                continue
            }
        }
    }

    convenience init(from bookUrl: FileItem, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Book", in: context)!
        self.init(entity: entity, insertInto: context)
        let fileURL = bookUrl.processedUrl!
        self.ext = fileURL.pathExtension
        self.identifier = fileURL.lastPathComponent
        let asset = AVAsset(url: fileURL)

        let titleFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String
        let authorFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String

        self.title = titleFromMeta ?? bookUrl.originalUrl.lastPathComponent.replacingOccurrences(of: "_", with: " ")
        self.author = authorFromMeta ?? "voiceover_unknown_author".localized
        self.duration = CMTimeGetSeconds(asset.duration)
        self.originalFileName = bookUrl.originalUrl.lastPathComponent
        self.isFinished = false
        self.usesDefaultArtwork = true

        if fileURL.pathExtension == "mp3" {
            self.loadMp3Data(from: asset)
        } else if let data = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? NSData {
            self.artworkData = data
            self.usesDefaultArtwork = false
        }

        self.setChapters(from: asset, context: context)

        let legacyIdentifier = bookUrl.originalUrl.lastPathComponent
        let storedTime = UserDefaults.standard.double(forKey: legacyIdentifier)

        // migration of time
        if storedTime > 0 {
            self.currentTime = storedTime
            UserDefaults.standard.removeObject(forKey: legacyIdentifier)
        }
    }
}
