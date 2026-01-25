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
  public class func getBookTitle(from fileURL: URL) -> String {
    let asset = AVAsset(url: fileURL)

    // Check all metadata items for title, regardless of format
    for item in asset.metadata {
      if let commonKey = item.commonKey?.rawValue,
         commonKey == "title",
         let title = item.value as? String {
        return title
      }
    }

    return fileURL.lastPathComponent
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
