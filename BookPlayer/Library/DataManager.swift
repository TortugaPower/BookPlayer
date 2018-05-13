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

class DataManager {
    static let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!

    // MARK: - Core Data stack

    static var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BookPlayer")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    class func saveContext () {
        let context = self.persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    /**
     *  Return array of file URLs
     */
    class func getLocalFilesURL() -> [URL]? {

        //get reference of all the files located inside the Documents folder
        guard let fileEnumerator = FileManager.default.enumerator(atPath: self.documentsPath) else {
            return nil
        }

        var urlArray = [URL]()

        if var filenameArray = fileEnumerator.map({ return $0}) as? [String] {
            self.process(&filenameArray, urls: &urlArray)
        }

        return urlArray
    }

    private class func process(_ files:inout [String], urls:inout [URL]) {
        if files.count == 0 {
            return
        }

        let filename = files.removeFirst()

        //ignore folder inbox
        if filename  == "Inbox" {
            return self.process(&files, urls: &urls)
        }

        let documentsURL = URL(fileURLWithPath: self.documentsPath)

        // which should return valid url strings
        let fileURL = documentsURL.appendingPathComponent(filename)

        //append if file isn't in list
        if !urls.contains(fileURL) {
            urls.append(fileURL)
        }

        return self.process(&files, urls: &urls)
    }

    /**
     *  Load local files and return array of Books
     */
    class func loadLibrary(completion:@escaping (Library) -> Void) {

        //load everything from DB
        var library: Library!

        let context = self.persistentContainer.viewContext
        let fetch: NSFetchRequest<Library> = Library.fetchRequest()
        do {
            library = try context.fetch(fetch).first ??
                Library.create(in: context)
        } catch {
            fatalError("Failed to fetch library")
        }

        //get reference of all the files located inside the Documents folder
        guard var urls = DataManager.getLocalFilesURL() else {
            return completion(library)
        }

        if let items = library.items?.array as? [LibraryItem] {
            //remove urls already transformed into books
            urls = urls.filter { (url) -> Bool in
                return !items.contains { (item) -> Bool in
                    //check if playlist
                    if let playlist = item as? Playlist,
                        let books = playlist.books?.array as? [Book] {
                        //check playlist books
                        return books.contains { (book) -> Bool in
                            if book.identifier == url.lastPathComponent {
                                book.load(fileURL: url)
                                return true
                            }
                            return false
                        }
                    }

                    //check book
                    if item.identifier == url.lastPathComponent,
                        let book = item as? Book {
                        book.load(fileURL: url)
                        return true
                    }
                    return false
                }
            }
        }

        DispatchQueue.global().async {
            //iterate and process files
            let context = self.persistentContainer.viewContext

            for fileURL in urls {
                // autoreleasepool needed to avoid OOM crashes from the file manager
                autoreleasepool { () -> Void in
                    let book = Book(from: fileURL, context: context)
                    library.addToItems(book)
                }
            }

            self.saveContext()

            DispatchQueue.main.async {
                completion(library)
            }
        }
    }

    class func createPlaylist(title: String, books: [Book]) -> Playlist {
        return Playlist(title: title, books: books, context: self.persistentContainer.viewContext)
    }
}
