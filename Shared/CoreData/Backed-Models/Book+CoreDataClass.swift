//
//  Book+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 BookPlayer LLC. All rights reserved.
//
//

import AVFoundation
import CoreData
import Foundation

@objc(Book)
public class Book: LibraryItem {
  enum CodingKeys: String, CodingKey {
    case currentTime, duration, relativePath, remoteURL, artworkURL, percentCompleted, title, details, folder, orderRank
  }

  public override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(currentTime, forKey: .currentTime)
    try container.encode(duration, forKey: .duration)
    try container.encode(relativePath, forKey: .relativePath)
    try? container.encode(remoteURL, forKey: .remoteURL)
    try? container.encode(artworkURL, forKey: .artworkURL)
    try container.encode(percentCompleted, forKey: .percentCompleted)
    try container.encode(title, forKey: .title)
    try container.encode(details, forKey: .details)
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
    relativePath = try values.decode(String.self, forKey: .relativePath)
    remoteURL = try? values.decode(URL.self, forKey: .remoteURL)
    artworkURL = try? values.decode(URL.self, forKey: .artworkURL)
    percentCompleted = try values.decode(Double.self, forKey: .percentCompleted)
    title = try values.decode(String.self, forKey: .title)
    details = try values.decode(String.self, forKey: .details)
  }
}

extension CodingUserInfoKey {
  public static let context = CodingUserInfoKey(rawValue: "context")
}

extension Book {
  public func loadChaptersIfNeeded(from asset: AVAsset, context: NSManagedObjectContext) -> Bool {
    guard chapters?.count == 0 else { return false }

    setChapters(from: asset, context: context)
    return true
  }

  public func setChapters(from asset: AVAsset, context: NSManagedObjectContext) {
    if !asset.availableChapterLocales.isEmpty {
      setStandardChapters(from: asset, context: context)
    } else {
      setOverdriveChapters(from: asset, context: context)
    }
  }

  /// Store chapters that are automatically parsed by the native SDK
  private func setStandardChapters(from asset: AVAsset, context: NSManagedObjectContext) {
    for locale in asset.availableChapterLocales {
      let chaptersMetadata = asset.chapterMetadataGroups(
        withTitleLocale: locale, containingItemsWithCommonKeys: [AVMetadataKey.commonKeyArtwork]
      )

      for (index, chapterMetadata) in chaptersMetadata.enumerated() {
        let chapterIndex = index + 1
        let chapter = Chapter(context: context)

        chapter.title = AVMetadataItem.metadataItems(
          from: chapterMetadata.items,
          withKey: AVMetadataKey.commonKeyTitle,
          keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String ?? ""
        chapter.start = CMTimeGetSeconds(chapterMetadata.timeRange.start)
        chapter.duration = CMTimeGetSeconds(chapterMetadata.timeRange.duration)
        chapter.index = Int16(chapterIndex)

        self.addToChapters(chapter)
      }
    }
  }

  /// Try to store chapters info from the TXXX tag for mp3s (used by Overdrive)
  /// Note: `XMLParser` does not have an async/await API, so I would rather use regex with
  /// what was introduced in iOS 16 to parse the info
  private func setOverdriveChapters(from asset: AVAsset, context: NSManagedObjectContext) {
    guard
      let fileURL,
      fileURL.pathExtension == "mp3",
      let overdriveMetadata = asset.metadata.first(where: { $0.identifier?.rawValue == "id3/TXXX" })?.value as? String
    else { return }

    let matches = overdriveMetadata.matches(of: /<Marker>(.+?)<\/Marker>/)
    var chapters = [Chapter]()

    for (index, match) in matches.enumerated() {
      let (_, marker) = match.output

      guard let (_, timeMatch) = marker.matches(of: /<Time>(.+?)<\/Time>/).first?.output else {
        continue
      }

      let chapter = Chapter(context: context)
      chapter.index = Int16(index + 1)
      chapter.start = TimeParser.getDuration(from: String(timeMatch))

      if let (_, nameMatch) = marker.matches(of: /<Name>(.+?)<\/Name>/).first?.output {
        chapter.title = String(nameMatch)
      } else {
        chapter.title = ""
      }

      chapters.append(chapter)
    }

    /// Overdrive markers do not include the duration, we have to parse it from the next chapter over
    for (index, chapter) in chapters.enumerated() {
      if index == chapters.endIndex - 1 {
        chapter.duration = self.duration - chapter.start
      } else {
        chapter.duration = chapters[index + 1].start - chapter.start
      }

      self.addToChapters(chapter)
    }
  }

  private func loadMp3Data(from asset: AVAsset) {
    for item in asset.metadata {
      guard let key = item.commonKey?.rawValue,
            let value = item.value else { continue }

      switch key {
      case "title":
        self.title = value as? String
      case "artist":
        if self.details == "voiceover_unknown_author".localized {
          self.details = value as? String
        }
      default:
        continue
      }
    }
  }

  public convenience init(from bookUrl: URL, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "Book", in: context)!
    self.init(entity: entity, insertInto: context)
    let fileURL = bookUrl
    self.relativePath = fileURL.relativePath(to: DataManager.getProcessedFolderURL())
    self.remoteURL = nil
    self.artworkURL = nil
    let asset = AVAsset(url: fileURL)

    let titleFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String
    let authorFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String

    self.title = titleFromMeta ?? bookUrl.lastPathComponent.replacingOccurrences(of: "_", with: " ")
    self.details = authorFromMeta ?? "voiceover_unknown_author".localized
    self.duration = CMTimeGetSeconds(asset.duration)
    self.originalFileName = bookUrl.lastPathComponent
    self.isFinished = false
    self.type = .book

    if fileURL.pathExtension == "mp3" {
      self.loadMp3Data(from: asset)
    }

    self.setChapters(from: asset, context: context)
  }

  public class func getBookTitle(from fileURL: URL) -> String {
    let asset = AVAsset(url: fileURL)

    let titleFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String

    return titleFromMeta ?? fileURL.lastPathComponent
  }
}

extension Book {
  public convenience init(
    syncItem: SyncableItem,
    context: NSManagedObjectContext
  ) {
    let entity = NSEntityDescription.entity(forEntityName: "Book", in: context)!
    self.init(entity: entity, insertInto: context)

    self.title = syncItem.title
    self.details = syncItem.details
    self.relativePath = syncItem.relativePath
    self.remoteURL = syncItem.remoteURL
    self.artworkURL = syncItem.artworkURL
    self.originalFileName = syncItem.originalFileName
    if let speed = syncItem.speed {
      self.speed = Float(speed)
    }
    self.currentTime = syncItem.currentTime
    self.duration = syncItem.duration
    self.percentCompleted = syncItem.percentCompleted
    self.isFinished = syncItem.isFinished
    self.orderRank = Int16(syncItem.orderRank)
    if let timestamp = syncItem.lastPlayDateTimestamp {
      self.lastPlayDate = Date(timeIntervalSince1970: timestamp)
    }
    self.type = .book
    // chapters will be loaded after the book is downloaded
  }
}

extension String {
  func matches(for regex: String, in text: String) -> [String] {
    do {
      let regex = try NSRegularExpression(pattern: regex)
      let results = regex.matches(
        in: text,
        range: NSRange(text.startIndex..., in: text)
      )
      return results.map {
        String(text[Range($0.range, in: text)!])
      }
    } catch let error {
      print("invalid regex: \(error.localizedDescription)")
      return []
    }
  }
}
