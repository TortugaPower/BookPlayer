//
//  AVPlayerItemExtensions.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 09.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import AVFoundation

extension AVPlayerItem {
    func getChapters() -> [Chapter] {
        var chapterIndex = 1
        var chapters = [Chapter]()

        for locale in asset.availableChapterLocales {
            let chaptersMetadata = self.asset.chapterMetadataGroups(withTitleLocale: locale, containingItemsWithCommonKeys: [AVMetadataKey.commonKeyArtwork])

            for chapterMetadata in chaptersMetadata {
                let chapter = Chapter(
                    title: AVMetadataItem.metadataItems(
                        from: chapterMetadata.items,
                        withKey: AVMetadataKey.commonKeyTitle,
                        keySpace: AVMetadataKeySpace.common
                        ).first?.value?.copy(with: nil) as? String ?? "Chapter \(chapterIndex)",
                    start: TimeInterval(CMTimeGetSeconds(chapterMetadata.timeRange.start)),
                    duration: TimeInterval(CMTimeGetSeconds(chapterMetadata.timeRange.duration)),
                    index: chapterIndex)

                chapters.append(chapter)

                chapterIndex += 1
            }
        }

        return chapters
    }
}
