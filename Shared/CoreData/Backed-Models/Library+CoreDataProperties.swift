//
//  Library+CoreDataProperties.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

extension Library {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Library> {
        return NSFetchRequest<Library>(entityName: "Library")
    }

    @nonobjc public class func create(in context: NSManagedObjectContext) -> Library {
        // swiftlint:disable force_cast
        return NSEntityDescription.insertNewObject(forEntityName: "Library", into: context) as! Library
      // swiftlint:enable force_cast
    }

    @NSManaged public var extractedThemes: NSOrderedSet?
    @NSManaged public var currentTheme: Theme!
    @NSManaged public var items: NSSet?
    @NSManaged public var lastPlayedItem: LibraryItem?
}

// MARK: Generated accessors for items

extension Library {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: LibraryItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: LibraryItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

    @objc(insertObject:inExtractedThemesAtIndex:)
    @NSManaged public func insertIntoExtractedThemes(_ value: Theme, at idx: Int)

    @objc(removeObjectFromExtractedThemesAtIndex:)
    @NSManaged public func removeFromExtractedThemes(at idx: Int)

    @objc(insertExtractedThemes:atIndexes:)
    @NSManaged public func insertIntoExtractedThemes(_ values: [Theme], at indexes: NSIndexSet)

    @objc(removeExtractedThemesAtIndexes:)
    @NSManaged public func removeFromExtractedThemes(at indexes: NSIndexSet)

    @objc(replaceObjectInExtractedThemesAtIndex:withObject:)
    @NSManaged public func replaceExtractedThemes(at idx: Int, with value: Theme)

    @objc(replaceExtractedThemesAtIndexes:withItems:)
    @NSManaged public func replaceExtractedThemes(at indexes: NSIndexSet, with values: [Theme])

    @objc(addExtractedThemesObject:)
    @NSManaged public func addToExtractedThemes(_ value: Theme)

    @objc(removeExtractedThemesObject:)
    @NSManaged public func removeFromExtractedThemes(_ value: Theme)

    @objc(addExtractedThemes:)
    @NSManaged public func addToExtractedThemes(_ values: NSOrderedSet)

    @objc(removeExtractedThemes:)
    @NSManaged public func removeFromExtractedThemes(_ values: NSOrderedSet)
}
