//
//  LibraryItem+CoreDataProperties.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 BookPlayer LLC. All rights reserved.
//
//

import CoreData
import Foundation

extension LibraryItem {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<LibraryItem> {
    return NSFetchRequest<LibraryItem>(entityName: "LibraryItem")
  }

  @NSManaged public var uuid: String
  @NSManaged public var currentTime: Double
  @NSManaged public var duration: Double
  @NSManaged public var title: String!
  @NSManaged public var percentCompleted: Double
  @NSManaged public var speed: Float
  @NSManaged public var library: Library?
  @NSManaged public var folder: Folder?
  @NSManaged public var isFinished: Bool
  @NSManaged public var lastPlayDate: Date?
  @NSManaged public var relativePath: String!
  @NSManaged public var remoteURL: URL?
  @NSManaged public var artworkURL: URL?
  @NSManaged public var originalFileName: String!
  @NSManaged public var orderRank: Int16
  @NSManaged public var bookmarks: NSSet?
  @NSManaged public var lastPlayed: Library?
  @NSManaged public var details: String!
  @NSManaged public var type: ItemType
  @NSManaged public var hardcoverBook: HardcoverBook?
  @NSManaged public var externalResources: NSSet?
}

// MARK: Generated accessors for externalResources
extension LibraryItem {
  @objc(addExternalResourcesObject:)
  @NSManaged public func addToExternalResources(_ value: ExternalResource)

  @objc(removeExternalResourcesObject:)
  @NSManaged public func removeFromExternalResources(_ value: ExternalResource)

  @objc(addExternalResources:)
  @NSManaged public func addToExternalResources(_ values: NSSet)

  @objc(removeExternalResources:)
  @NSManaged public func removeFromExternalResources(_ values: NSSet)
  
  public var resourcesArray: [ExternalResource] {
    return externalResources?.allObjects as? [ExternalResource] ?? []
  }
  
  public var jellyfinResource: ExternalResource? {
    return resourcesArray.first { $0.providerName == ExternalResource.ProviderName.jellyfin.rawValue }
  }
}

// MARK: Generated accessors for bookmarks

extension LibraryItem {
  @objc(addBookmarksObject:)
  @NSManaged public func addToBookmarks(_ value: Bookmark)

  @objc(removeBookmarksObject:)
  @NSManaged public func removeFromBookmarks(_ value: Bookmark)

  @objc(addBookmarks:)
  @NSManaged public func addToBookmarks(_ values: NSSet)

  @objc(removeBookmarks:)
  @NSManaged public func removeFromBookmarks(_ values: NSSet)
}
