//
//  DataManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/30/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import CoreData

public class DataManager {
    static let queue = OperationQueue()

    // MARK: - Folder URLs

    // MARK: - Operations
    public class func start(_ operation: Operation) {
        self.queue.addOperation(operation)
    }

    public class func isProcessingFiles() -> Bool {
        return !self.queue.operations.isEmpty
    }

    // MARK: - Core Data stack

    private static var persistentContainer: NSPersistentContainer = {
        let name = "BookPlayerKit"
        let groupIdentifier = "group.tortugapower.bookplayer.files"
        let container = NSPersistentContainer(name: name)

        var persistentStoreDescriptions: NSPersistentStoreDescription

        let storeUrl =  FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)!.appendingPathComponent("\(name).sqlite")

        let description = NSPersistentStoreDescription()
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.url = storeUrl

        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)!.appendingPathComponent("\(name).sqlite"))]

        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        return container
    }()

    public class func getContext() -> NSManagedObjectContext {
        return self.persistentContainer.viewContext
    }

    public class func getBackgroundContext() -> NSManagedObjectContext {
        return self.persistentContainer.newBackgroundContext()
    }

    public class func saveContext () {
        let context = self.persistentContainer.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    // MARK: - Models handler

    /**
     Gets the library for the App. There should be only one Library object at all times
     */
    public class func getLibrary() -> Library {
        var library: Library!

        let context = self.persistentContainer.viewContext
        let fetch: NSFetchRequest<Library> = Library.fetchRequest()

        do {
            library = try context.fetch(fetch).first ??
                Library.create(in: context)

        } catch {
            fatalError("Failed to fetch library")
        }

        return library
    }

    /**
     Gets a stored book from an identifier.
     */
    public class func getBook(with identifier: String, from library: Library) -> Book? {
        guard let item = library.getItem(with: identifier) else {
            return nil
        }

        guard let playlist = item as? Playlist else {
            return item as? Book
        }

        return playlist.getBook(with: identifier)
    }

    func insert(_ playlist: Playlist, into library: Library) {
        library.addToItems(playlist)
        DataManager.saveContext()
    }

    func delete(_ item: NSManagedObject) {
        let context = DataManager.getContext()
        context.delete(item)
        DataManager.saveContext()
    }
}
