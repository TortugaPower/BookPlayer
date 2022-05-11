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

  public override func getItem(with relativePath: String) -> LibraryItem? {
    return self.relativePath == relativePath ? self : nil
  }

  public override func getFolder(matching relativePath: String) -> Folder? {
    return self.folder?.getFolder(matching: relativePath)
  }

  public override func getBookToPlay() -> Book? {
    return self
  }

  public func previousBook() -> LibraryItem? {
    if
      let folder = self.folder,
      folder.type == .folder,
      let previous = folder.getPreviousBook(before: self.relativePath) {
      return previous
    }

    return self.getLibrary()?.getPreviousBook(before: self.relativePath)
  }

  public func nextBook(autoplayed: Bool) -> LibraryItem? {
    if
      let folder = self.folder,
      folder.type == .folder,
      let next = folder.getNextBook(after: self.relativePath) {
      return next
    }

    if autoplayed {
      guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled.rawValue) else {
        return nil
      }
    }

    return self.getLibrary()?.getNextBook(after: self.relativePath)
  }

  enum CodingKeys: String, CodingKey {
    case currentTime, duration, relativePath, percentCompleted, title, details, folder, orderRank
  }

  public override func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(currentTime, forKey: .currentTime)
    try container.encode(duration, forKey: .duration)
    try container.encode(relativePath, forKey: .relativePath)
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
    percentCompleted = try values.decode(Double.self, forKey: .percentCompleted)
    title = try values.decode(String.self, forKey: .title)
    details = try values.decode(String.self, forKey: .details)
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
        if self.details == "voiceover_unknown_author".localized {
          self.details = value as? String
        }
      default:
        continue
      }
    }
  }

  public convenience init(
    context: NSManagedObjectContext,
    title: String,
    details: String,
    relativePath: String,
    originalFileName: String,
    speed: Float?,
    currentTime: Double,
    duration: Double,
    percentCompleted: Double,
    isFinished: Bool,
    orderRank: Int16,
    lastPlayDate: Date?
  ) {
    let entity = NSEntityDescription.entity(forEntityName: "Book", in: context)!
    self.init(entity: entity, insertInto: context)

    self.title = title
    self.details = details
    self.relativePath = relativePath
    self.originalFileName = originalFileName
    if let speed = speed {
      self.speed = speed
    }
    self.currentTime = currentTime
    self.duration = duration
    self.percentCompleted = percentCompleted
    self.isFinished = isFinished
    self.orderRank = orderRank
    self.lastPlayDate = lastPlayDate
    // chapters will be loaded after the book is downloaded
  }

  public convenience init(from bookUrl: URL, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "Book", in: context)!
    self.init(entity: entity, insertInto: context)
    let fileURL = bookUrl
    self.relativePath = fileURL.relativePath(to: DataManager.getProcessedFolderURL())
    let asset = AVAsset(url: fileURL)

    let titleFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String
    let authorFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String

    self.title = titleFromMeta ?? bookUrl.lastPathComponent.replacingOccurrences(of: "_", with: " ")
    self.details = authorFromMeta ?? "voiceover_unknown_author".localized
    self.duration = CMTimeGetSeconds(asset.duration)
    self.originalFileName = bookUrl.lastPathComponent
    self.isFinished = false

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
