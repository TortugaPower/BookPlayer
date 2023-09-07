//
//  Book+CoreDataProperties.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

extension Book {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Book> {
    return NSFetchRequest<Book>(entityName: "Book")
  }

  @nonobjc public class func find(with identifier: String, context: NSManagedObjectContext) -> Book? {
    let request: NSFetchRequest<Book> = Book.fetchRequest()

    request.predicate = NSPredicate(format: "identifier = %@", identifier)

    return try? context.fetch(request).first
  }

  @nonobjc public class func find(at path: String, context: NSManagedObjectContext) -> Book? {
    let request: NSFetchRequest<Book> = Book.fetchRequest()

    request.predicate = NSPredicate(format: "path = %@", path)

    return try? context.fetch(request).first
  }

  @NSManaged public var chapters: NSOrderedSet?
}

// MARK: Generated accessors for chapters

extension Book {
  @objc(insertObject:inChaptersAtIndex:)
  @NSManaged public func insertIntoChapters(_ value: Chapter, at idx: Int)

  @objc(removeObjectFromChaptersAtIndex:)
  @NSManaged public func removeFromChapters(at idx: Int)

  @objc(insertChapters:atIndexes:)
  @NSManaged public func insertIntoChapters(_ values: [Chapter], at indexes: NSIndexSet)

  @objc(removeChaptersAtIndexes:)
  @NSManaged public func removeFromChapters(at indexes: NSIndexSet)

  @objc(replaceObjectInChaptersAtIndex:withObject:)
  @NSManaged public func replaceChapters(at idx: Int, with value: Chapter)

  @objc(replaceChaptersAtIndexes:withChapters:)
  @NSManaged public func replaceChapters(at indexes: NSIndexSet, with values: [Chapter])

  @objc(addChaptersObject:)
  @NSManaged public func addToChapters(_ value: Chapter)

  @objc(removeChaptersObject:)
  @NSManaged public func removeFromChapters(_ value: Chapter)

  @objc(addChapters:)
  @NSManaged public func addToChapters(_ values: NSOrderedSet)

  @objc(removeChapters:)
  @NSManaged public func removeFromChapters(_ values: NSOrderedSet)
}
