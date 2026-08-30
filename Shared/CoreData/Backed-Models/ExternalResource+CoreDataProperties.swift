//
//  ExternalResource+CoreDataProperties.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 13/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import CoreData

@objc(ExternalResource)
public class ExternalResource: NSManagedObject {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<ExternalResource> {
    return NSFetchRequest<ExternalResource>(entityName: "ExternalResource")
  }

  @NSManaged public var id: Int32
  @NSManaged public var providerName: String
  @NSManaged public var providerId: String
  @NSManaged public var syncStatus: String
  @NSManaged public var lastSyncedAt: Date?
  @NSManaged public var processedFile: Bool
  @NSManaged public var hostId: String?
  
  @NSManaged public var libraryItem: LibraryItem?
  
  @nonobjc public class func create(
    _ item: SimpleExternalResource,
    libraryItem: LibraryItem?,
    in context: NSManagedObjectContext
  ) -> ExternalResource {
    // swiftlint:disable:next force_cast
    let entity = NSEntityDescription.insertNewObject(forEntityName: "ExternalResource", into: context) as! ExternalResource

    // truncatingIfNeeded: snapshot ids from the import builders are abs(UUID().hashValue)
    // — almost always beyond Int32.max, and Int32(exactly-style init) would trap. The
    // field is a local row marker, not identity (that's (providerName, providerId)).
    entity.id = Int32(truncatingIfNeeded: item.id)
    entity.providerName = item.providerName
    entity.providerId = item.providerId
    entity.lastSyncedAt = item.lastSyncedAt
    entity.syncStatus = item.syncStatus
    entity.processedFile = item.processedFile
    entity.hostId = item.hostId
    
    if let item = libraryItem {
      entity.libraryItem = item
    }

    return entity
  }
  
  @nonobjc public class func create(
    _ item: SyncableExternalResource,
    libraryItem: LibraryItem?,
    in context: NSManagedObjectContext
  ) -> ExternalResource {
    // swiftlint:disable:next force_cast
    let entity = NSEntityDescription.insertNewObject(forEntityName: "ExternalResource", into: context) as! ExternalResource

    entity.providerName = item.providerName
    entity.providerId = item.providerId
    entity.lastSyncedAt = item.lastSyncedAt
    entity.syncStatus = item.syncStatus
    entity.processedFile = item.processedFile
    entity.hostId = item.hostId
    
    if let item = libraryItem {
      entity.libraryItem = item
    }

    return entity
  }
}
