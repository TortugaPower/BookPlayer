//
//  DataManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/3/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

public class DataManager {
    public static let processedFolderName = "Processed"
    public static let inboxFolderName = "Inbox"

    // MARK: - Folder URLs

    public class func getDocumentsFolderURL() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    public class func getProcessedFolderURL() -> URL {
        let documentsURL = self.getDocumentsFolderURL()

        let processedFolderURL = documentsURL.appendingPathComponent(self.processedFolderName)

        if !FileManager.default.fileExists(atPath: processedFolderURL.path) {
            do {
                try FileManager.default.createDirectory(at: processedFolderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Couldn't create Processed folder")
            }
        }

        return processedFolderURL
    }

    public class func getInboxFolderURL() -> URL {
        let documentsURL = self.getDocumentsFolderURL()

        let inboxFolderURL = documentsURL.appendingPathComponent(self.inboxFolderName)

        if !FileManager.default.fileExists(atPath: inboxFolderURL.path) {
            do {
                try FileManager.default.createDirectory(at: inboxFolderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Couldn't create Inbox folder")
            }
        }

        return inboxFolderURL
    }

    public static var coreDataStack: CoreDataStack = {
        let manager = DataMigrationManager(modelNamed: "BookPlayer",
                                           enableMigrations: true)
        return manager.stack
    }()

    public class func getContext() -> NSManagedObjectContext {
        return self.coreDataStack.managedContext
    }

    public class func saveContext() {
        self.coreDataStack.saveContext()
    }

    public class func getBackgroundContext() -> NSManagedObjectContext {
        return self.coreDataStack.getBackgroundContext()
    }

    // MARK: - Models handler

    /**
     Gets the library for the App. There should be only one Library object at all times
     */
    public class func getLibrary() -> Library {
        var library: Library!

        let context = self.coreDataStack.managedContext
        let fetch: NSFetchRequest<Library> = Library.fetchRequest()

        do {
            library = try context.fetch(fetch).first ??
                Library.create(in: context)
        } catch {
            fatalError("Failed to fetch library")
        }

        return library
    }

    public class func getBooks() -> [Book]? {
        let fetch: NSFetchRequest<Book> = Book.fetchRequest()
        let context = self.coreDataStack.managedContext

        return try? context.fetch(fetch)
    }

    /**
     Gets a stored book from an identifier.
     */
    public class func getBook(with identifier: String, from library: Library) -> Book? {
        guard let item = library.getItem(with: identifier)
        else {
            return nil
        }

        return item as? Book
    }

    public class func createFolder(from url: URL, items: [LibraryItem]) -> Folder {
        return Folder(from: url, items: items, context: self.getContext())
    }

    public class func createFolder(title: String, items: [LibraryItem]) -> Folder {
        return Folder(title: title, items: items, context: self.getContext())
    }

    public class func insert(_ folder: Folder, into library: Library, at index: Int? = nil) {
        if let index = index {
            library.insertIntoItems(folder, at: index)
        } else {
            library.addToItems(folder)
        }
        self.saveContext()
    }

    public class func insert(_ item: LibraryItem, into folder: Folder, at index: Int? = nil) {
        if let index = index {
            folder.insertIntoItems(item, at: index)
        } else {
            folder.addToItems(item)
        }
        self.saveContext()
    }

    public class func delete(_ item: NSManagedObject) {
        self.coreDataStack.managedContext.delete(item)
        self.saveContext()
    }

    public class func jumpToStart(_ item: LibraryItem) {
        item.jumpToStart()
        item.markAsFinished(false)
        self.saveContext()
    }

    public class func mark(_ item: LibraryItem, asFinished: Bool) {
        item.markAsFinished(asFinished)
        self.saveContext()
    }

    // MARK: - TimeRecord

    public class func getPlaybackRecord() -> PlaybackRecord {
        let calendar = Calendar.current

        let today = Date()
        let dateFrom = calendar.startOfDay(for: today)
        let dateTo = calendar.date(byAdding: .day, value: 1, to: dateFrom)!

        // Set predicate as date being today's date
        let fromPredicate = NSPredicate(format: "date >= %@", dateFrom as NSDate)
        let toPredicate = NSPredicate(format: "date < %@", dateTo as NSDate)
        let datePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fromPredicate, toPredicate])

        let context = self.coreDataStack.managedContext
        let fetch: NSFetchRequest<PlaybackRecord> = PlaybackRecord.fetchRequest()
        fetch.predicate = datePredicate

        let record = try? context.fetch(fetch).first

        return record ?? PlaybackRecord.create(in: context)
    }

    public class func getPlaybackRecords(from startDate: Date, to endDate: Date) -> [PlaybackRecord]? {
        let fromPredicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        let toPredicate = NSPredicate(format: "date < %@", endDate as NSDate)
        let datePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fromPredicate, toPredicate])

        let fetch: NSFetchRequest<PlaybackRecord> = PlaybackRecord.fetchRequest()
        fetch.predicate = datePredicate
        let context = self.coreDataStack.managedContext

        return try? context.fetch(fetch)
    }

    public class func recordTime(_ playbackRecord: PlaybackRecord) {
        playbackRecord.time += 1
        self.saveContext()
    }
}
