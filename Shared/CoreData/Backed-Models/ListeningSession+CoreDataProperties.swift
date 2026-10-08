//
//  ListeningSession+CoreDataProperties.swift
//  BookPlayerKit
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//
//

import CoreData
import Foundation

extension ListeningSession {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<ListeningSession> {
    return NSFetchRequest<ListeningSession>(entityName: "ListeningSession")
  }

  @nonobjc public class func create(in context: NSManagedObjectContext) -> ListeningSession {
    // swiftlint:disable force_cast
    return NSEntityDescription.insertNewObject(forEntityName: "ListeningSession", into: context) as! ListeningSession
    // swiftlint:enable force_cast
  }

  @NSManaged public var id: String
  @NSManaged public var relativePath: String
  /// Primary display title (folder breadcrumb, bound title, or book title).
  @NSManaged public var itemTitle: String
  /// Secondary line (book title under a folder, or outer folder under a bound book).
  @NSManaged public var subtitle: String?
  /// Preferred artwork path (usually the nearest folder); falls back to `relativePath`.
  @NSManaged public var artworkRelativePath: String?
  @NSManaged public var startedAt: Date
  @NSManaged public var endedAt: Date?
  @NSManaged public var duration: Double
}
