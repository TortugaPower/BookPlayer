//
//  Library+CoreDataProperties.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
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
    }

    @NSManaged public var extractedThemes: NSOrderedSet?
    @NSManaged public var currentTheme: Theme!
    @NSManaged public var items: NSOrderedSet?
}

// MARK: Generated accessors for items

extension Library {
    @objc(insertObject:inItemsAtIndex:)
    @NSManaged public func insertIntoItems(_ value: LibraryItem, at idx: Int)

    @objc(removeObjectFromItemsAtIndex:)
    @NSManaged public func removeFromItems(at idx: Int)

    @objc(insertItems:atIndexes:)
    @NSManaged public func insertIntoItems(_ values: [LibraryItem], at indexes: NSIndexSet)

    @objc(removeItemsAtIndexes:)
    @NSManaged public func removeFromItems(at indexes: NSIndexSet)

    @objc(replaceObjectInItemsAtIndex:withObject:)
    @NSManaged public func replaceItems(at idx: Int, with value: LibraryItem)

    @objc(replaceItemsAtIndexes:withItems:)
    @NSManaged public func replaceItems(at indexes: NSIndexSet, with values: [LibraryItem])

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: LibraryItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: LibraryItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSOrderedSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSOrderedSet)

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
