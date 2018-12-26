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

    @NSManaged public var availableThemes: NSOrderedSet?
    @NSManaged public var currentTheme: Theme?
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

    @objc(insertObject:inAvailableThemesAtIndex:)
    @NSManaged public func insertIntoAvailableThemes(_ value: Theme, at idx: Int)

    @objc(removeObjectFromAvailableThemesAtIndex:)
    @NSManaged public func removeFromAvailableThemes(at idx: Int)

    @objc(insertAvailableThemes:atIndexes:)
    @NSManaged public func insertIntoAvailableThemes(_ values: [Theme], at indexes: NSIndexSet)

    @objc(removeAvailableThemesAtIndexes:)
    @NSManaged public func removeFromAvailableThemes(at indexes: NSIndexSet)

    @objc(replaceObjectInAvailableThemesAtIndex:withObject:)
    @NSManaged public func replaceAvailableThemes(at idx: Int, with value: Theme)

    @objc(replaceAvailableThemesAtIndexes:withItems:)
    @NSManaged public func replaceAvailableThemes(at indexes: NSIndexSet, with values: [Theme])

    @objc(addAvailableThemesObject:)
    @NSManaged public func addToAvailableThemes(_ value: Theme)

    @objc(removeAvailableThemesObject:)
    @NSManaged public func removeFromAvailableThemes(_ value: Theme)

    @objc(addAvailableThemes:)
    @NSManaged public func addToAvailableThemes(_ values: NSOrderedSet)

    @objc(removeAvailableThemes:)
    @NSManaged public func removeFromAvailableThemes(_ values: NSOrderedSet)
}
