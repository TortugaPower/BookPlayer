//
//  DataManager+CoreData.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/3/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

extension DataManager {
    internal static var persistentContainer: NSPersistentContainer = {
        let name = "BookPlayer"

        let container = NSPersistentContainer(name: name)

        let description = NSPersistentStoreDescription()
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.url = storeUrl

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        return container
    }()

    class func saveContext() {
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
    class func getLibrary() -> Library {
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

    class func getBooks() -> [Book]? {
        let fetch: NSFetchRequest<Book> = Book.fetchRequest()
        let context = self.persistentContainer.viewContext

        return try? context.fetch(fetch)
    }

    /**
     Gets a stored book from an identifier.
     */
    class func getBook(with identifier: String, from library: Library) -> Book? {
        guard let item = library.getItem(with: identifier) else {
            return nil
        }

        guard let playlist = item as? Playlist else {
            return item as? Book
        }

        return playlist.getBook(with: identifier)
    }

    /**
     Creates a book for each URL and adds it to the specified playlist. If no playlist is specified, it will be added to the library.

     A book can't be in two places at once, so if it already existed, it will be removed from the original playlist or library, and it will be added to the new one.

     - Parameter files: `Book`s will be created for each element in this array
     - Parameter playlist: `Playlist` to which the created `Book` will be added
     - Parameter library: `Library` to which the created `Book` will be added if the parameter `playlist` is nil
     - Parameter completion: Closure fired after processing all the urls.
     */
    class func insertBooks(from files: [FileItem], into playlist: Playlist?, or library: Library, completion: @escaping () -> Void) {
        let context = self.persistentContainer.viewContext

        for file in files {
            // TODO: do something about unprocessed URLs
            guard let url = file.processedUrl else { continue }

            // Check if book exists in the library
            guard let item = library.getItem(with: url) else {
                let book = Book(from: file, context: context)

                if let playlist = playlist {
                    playlist.addToBooks(book)
                } else {
                    library.addToItems(book)
                }

                continue
            }

            guard let storedPlaylist = item as? Playlist,
                let storedBook = storedPlaylist.getBook(with: url) else {
                // swiftlint:disable force_cast
                // Handle if item is a book
                let storedBook = item as! Book

                if let playlist = playlist {
                    library.removeFromItems(storedBook)
                    playlist.addToBooks(storedBook)
                }

                continue
            }

            // Handle if book already exists in the library
            storedPlaylist.removeFromBooks(storedBook)

            if let playlist = playlist {
                playlist.addToBooks(storedBook)
            } else {
                library.addToItems(storedBook)
            }
        }

        self.saveContext()

        DispatchQueue.main.async {
            completion()
        }
    }

    /**
     Creates a book for each URL and adds it to the library. A book can't be in two places at once, so it will be removed if it already existed in a playlist.

     - Parameter bookUrls: `Book`s will be created for each element in this array
     - Parameter library: `Library` to which the created `Book` will be added
     - Parameter completion: Closure fired after processing all the urls.
     */
    class func insertBooks(from files: [FileItem], into library: Library, completion: @escaping () -> Void) {
        self.insertBooks(from: files, into: nil, or: library, completion: completion)
    }

    /**
     Creates a book for each URL and adds it to the specified playlist. A book can't be in two places at once, so it will be removed from the library if it already existed.

     - Parameter bookUrls: `Book`s will be created for each element in this array
     - Parameter playlist: `Playlist` to which the created `Book` will be added
     - Parameter completion: Closure fired after processing all the urls.
     */
    class func insertBooks(from files: [FileItem], into playlist: Playlist, completion: @escaping () -> Void) {
        self.insertBooks(from: files, into: playlist, or: playlist.library!, completion: completion)
    }

    class func createPlaylist(title: String, books: [Book]) -> Playlist {
        return Playlist(title: title, books: books, context: self.persistentContainer.viewContext)
    }

    class func createBook(from file: FileItem) -> Book {
        return Book(from: file, context: self.persistentContainer.viewContext)
    }

    class func insert(_ playlist: Playlist, into library: Library, at index: Int? = nil) {
        if let index = index {
            library.insertIntoItems(playlist, at: index)
        } else {
            library.addToItems(playlist)
        }
        self.saveContext()
    }

    class func delete(_ item: NSManagedObject) {
        self.persistentContainer.viewContext.delete(item)
        self.saveContext()
    }

    class func delete(_ items: [LibraryItem], mode: DeleteMode = .deep) {
        for item in items {
            guard let playlist = item as? Playlist else {
                // swiftlint:disable force_cast
                self.delete(item as! Book, mode: mode)
                continue
            }

            self.delete(playlist, mode: mode)
        }
    }

    class func delete(_ playlist: Playlist, mode: DeleteMode = .deep) {
        guard let library = playlist.library else { return }

        if mode == .shallow,
            let orderedSet = playlist.books {
            library.addToItems(orderedSet)
        }

        // swiftlint:disable force_cast
        for book in playlist.books?.array as! [Book] {
            guard mode == .deep else { continue }
            self.delete(book)
        }

        library.removeFromItems(playlist)

        self.delete(playlist)
    }

    class func delete(_ book: Book, mode: DeleteMode = .deep) {
        guard mode == .deep else {
            if let playlist = book.playlist,
                let library = playlist.library {
                library.addToItems(book)

                playlist.removeFromBooks(book)

                self.saveContext()
            }

            return
        }

        if book == PlayerManager.shared.currentBook {
            PlayerManager.shared.stop()
        }

        let fileURL = book.fileURL

        DispatchQueue.global().async {
            if let fileURL = fileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        self.delete(book)
    }

    class func jumpToStart(_ item: LibraryItem) {
        item.jumpToStart()
        item.markAsFinished(false)
        self.saveContext()
    }

    class func mark(_ item: LibraryItem, asFinished: Bool) {
        item.markAsFinished(asFinished)
        self.saveContext()
    }

    // MARK: - TimeRecord

    class func getPlaybackRecord() -> PlaybackRecord {
        let calendar = Calendar.current

        let today = Date()
        let dateFrom = calendar.startOfDay(for: today)
        let dateTo = calendar.date(byAdding: .day, value: 1, to: dateFrom)!

        // Set predicate as date being today's date
        let fromPredicate = NSPredicate(format: "%@ >= %@", today as NSDate, dateFrom as NSDate)
        let toPredicate = NSPredicate(format: "%@ < %@", today as NSDate, dateTo as NSDate)
        let datePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fromPredicate, toPredicate])

        let context = self.persistentContainer.viewContext
        let fetch: NSFetchRequest<PlaybackRecord> = PlaybackRecord.fetchRequest()
        fetch.predicate = datePredicate

        let record = try? context.fetch(fetch).first

        return record ?? PlaybackRecord.create(in: context)
    }

    class func recordTime(_ playbackRecord: PlaybackRecord) {
        playbackRecord.time += 1
        self.saveContext()
    }
}
