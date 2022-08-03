//
//  Book+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import AVFoundation
import CoreData
import Foundation

@objc(Book)
public class Book: LibraryItem {
  var filename: String {
    return self.title + "." + self.ext
  }

  // needed to invalide cache of folder
  override public func setCurrentTime(_ time: Double) {
    self.currentTime = time
    self.folder?.resetCachedProgress()
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

extension Book {
  public func setChapters(from asset: AVAsset, context: NSManagedObjectContext) {
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
      default:
        continue
      }
    }
  }

  public convenience init(from bookUrl: URL, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "Book", in: context)!
    self.init(entity: entity, insertInto: context)
    let fileURL = bookUrl
    self.ext = fileURL.pathExtension
    self.identifier = fileURL.lastPathComponent
    self.relativePath = fileURL.relativePath(to: DataManager.getProcessedFolderURL())
    let asset = AVAsset(url: fileURL)

    let titleFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String
    let authorFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String

    self.title = titleFromMeta ?? bookUrl.lastPathComponent.replacingOccurrences(of: "_", with: " ")
    self.author = authorFromMeta ?? "voiceover_unknown_author".localized
    self.duration = CMTimeGetSeconds(asset.duration)
    self.originalFileName = bookUrl.lastPathComponent
    self.isFinished = false

    if fileURL.pathExtension == "mp3" {
      self.loadMp3Data(from: asset)
    }

    self.setChapters(from: asset, context: context)

    let legacyIdentifier = bookUrl.lastPathComponent
    let storedTime = UserDefaults.standard.double(forKey: legacyIdentifier)

    // migration of time
    if storedTime > 0 {
      self.currentTime = storedTime
      UserDefaults.standard.removeObject(forKey: legacyIdentifier)
    }
  }

  public class func getBookTitle(from fileURL: URL) -> String {
    let asset = AVAsset(url: fileURL)

    let titleFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String

    return titleFromMeta ?? fileURL.lastPathComponent
  }
}
