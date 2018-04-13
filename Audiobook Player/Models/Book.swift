//
//  Book.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 09.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import AVFoundation

class Book: NSObject {
    // MARK: Meta data

    var artwork: UIImage
    var asset: AVAsset
    var fileURL: URL
    var title: String = ""
    var author: String = ""

    var identifier: String {
        return self.fileURL.lastPathComponent
    }

    var displayTitle: String {
        return title + " - " + author
    }

    // MARK: Time

    var duration: TimeInterval {
        return TimeInterval(CMTimeGetSeconds(self.asset.duration))
    }

    var currentTime: TimeInterval = 0.0 {
        didSet {
            // Store state only every 2 seconds, I/O can be expensive
            if Int(self.currentTime) % 2 == 0 && self.currentTime != oldValue {
                UserDefaults.standard.set(self.currentTime, forKey: self.identifier)
            }

            self.updateCurrentChapter()
            self.updatePercentCompleted()
        }
    }

    private func getStoredTime() -> TimeInterval {
        // get stored value for current time of book in seconds
        var lastPlayedPosition = UserDefaults.standard.double(forKey: self.identifier)

        // If smartRewind is enabled and time since last play was 10 minutes (600s), rewind audiobook by 30 seconds or to start.
        if
            let lastPlayTime = UserDefaults.standard.object(forKey: UserDefaultsConstants.lastPauseTime+"_\(self.identifier)") as? Date,
            UserDefaults.standard.bool(forKey: UserDefaultsConstants.smartRewindEnabled)
        {
            if Date().timeIntervalSince(lastPlayTime) >= 600.0 {
                lastPlayedPosition = max(lastPlayedPosition - 30.0, 0)

                UserDefaults.standard.set(nil, forKey: UserDefaultsConstants.lastPauseTime+"_\(self.identifier)")
            }
        }

        return lastPlayedPosition
    }

    var percentCompleted: Int = 0
    var percentCompletedString: String = "0%"

    private func updatePercentCompleted() {
        var percentage = 0

        // Make sure not to try to divide by zero accidentially
        if currentTime >= 0.0 && duration > 0.0 {
            percentage = Int(round(currentTime / duration * 100))
        }

        if percentage == self.percentCompleted {
            return
        }

        self.percentCompleted = percentage
        self.percentCompletedString = "\(percentage)%"

        // Save to defaults
        UserDefaults.standard.set(percentage, forKey: self.identifier + "_percentage_completed")

        // Notify
        NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.updatePercentage, object: nil, userInfo: [
            "percentCompletedString": percentCompletedString,
            "fileURL": self.fileURL
        ] as [String: Any])
    }

    // MARK: Chapters

    var chapters: [Chapter] = [] {
        didSet {
            self.updateCurrentChapter()
        }
    }
    var currentChapter: Chapter?
    private var cachedChapter: Chapter?

    private func updateCurrentChapter() {
        // Don't change anything if we have no chapter or are still in range of the current
        if
            !self.chapters.isEmpty,
            self.cachedChapter != nil,
            let chapter = self.cachedChapter,
            (chapter.start + chapter.duration) > self.currentTime && chapter.start <= self.currentTime
        {
            return
        }

        for chapter in self.chapters where chapter.start >= self.currentTime {
            self.cachedChapter = chapter

            break
        }

        currentChapter = self.cachedChapter
    }

    // MARK: Live cycle

    init(fromFileURL fileURL: URL) {
        self.fileURL = fileURL
        self.asset = AVAsset(url: fileURL)

        let titleFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String
        let authorFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String

        self.title = titleFromMeta ?? fileURL.lastPathComponent.replacingOccurrences(of: "_", with: " ")
        self.author = authorFromMeta ?? "Unknown Author"

        if let artwork = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? Data {
            self.artwork = UIImage(data: artwork)!
        } else {
            self.artwork = UIImage()
        }

        super.init()

        self.currentTime = self.getStoredTime()
        self.updatePercentCompleted()
        self.updateCurrentChapter()
    }
}
