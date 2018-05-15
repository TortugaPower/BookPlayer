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
import IDZSwiftCommonCrypto

class DataManager {
    private class func getDocumentsFolderURL() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    class func getProcessedFolderURL() -> URL {
        let documentsURL = self.getDocumentsFolderURL()
        let folderName = "Processed"

        let processedFolderURL = documentsURL.appendingPathComponent(folderName)

        if !FileManager.default.fileExists(atPath: processedFolderURL.path) {
            do {
                try FileManager.default.createDirectory(at: processedFolderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Couldn't create Processed folder")
            }
        }

        return processedFolderURL
    }

    // MARK: - Core Data stack

    private static var persistentContainer: NSPersistentContainer = {
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
    private class func getPendingFilesURL() -> [URL]? {
        let documentsURL = self.getDocumentsFolderURL()
        //get reference of all the files located inside the Documents folder
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants)

            return filterFiles(urls)
        } catch {
            fatalError("Error fetching pending file urls")
        }

        return nil
    }

    private class func getProcessedFilesURL() -> [URL]? {
        //get reference of all the files located inside the Documents folder
        let processedFolderURL = self.getProcessedFolderURL()

        do {
            let urls = try FileManager.default.contentsOfDirectory(at: processedFolderURL, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants)
            return filterFiles(urls)
        } catch {
            fatalError("Error fetching pending file urls")
        }

        return nil
    }

    /**
     *  Return array of file URLs
     */
    private class func filterFiles(_ urls: [URL]) -> [URL] {
        return urls.filter({ !$0.hasDirectoryPath })
    }

    private class func processFile(at origin: URL, destinationFolder: URL) -> String? {

        guard let data = FileManager.default.contents(atPath: origin.path),
            let digest = Digest(algorithm: .md5).update(data: data)?.final() else {
                return nil
        }

        let hash = hexString(fromArray: digest)
        let filename = hash + ".\(origin.pathExtension)"
        let destinationURL = destinationFolder.appendingPathComponent(filename)

        do {
            try FileManager.default.moveItem(at: origin, to: destinationURL)
        } catch {
            fatalError("Fail to move file from \(origin) to \(destinationURL)")
        }

        return hash
    }

    /**
     *  Load local files and return array of Books
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

    class func processPendingFiles(completion:@escaping ([Book]) -> Void) {
        var books = [Book]()

        //get reference of all the files located inside the Documents folder
        guard let urls = self.getPendingFilesURL() else {
            return completion(books)
        }

        DispatchQueue.global().async {
            //iterate and process files
            let context = self.persistentContainer.viewContext

            for fileURL in urls {
                // autoreleasepool needed to avoid OOM crashes from the file manager
                autoreleasepool { () -> Void in
                    let book = Book(from: fileURL, context: context)
                    print(book.fileURL)
                    books.append(book)
                }
            }

            DispatchQueue.main.async {
                completion(books)
            }
        }
    }

    class func insert(_ books: [Book], into library: Library, completion:@escaping () -> Void) {

        DispatchQueue.global().async {
            let destinationFolder = self.getProcessedFolderURL()

            for book in books {
                guard let hash = self.processFile(at: book.fileURL, destinationFolder: destinationFolder) else {
                    continue
                }

                book.identifier = hash
                book.fileURL = destinationFolder.appendingPathComponent(book.filename)

                if let index = library.index(of: book),
                    let storedBook = library.getItem(at: index) as? Book {
                    book.currentTime = storedBook.currentTime
                    library.replaceItems(at: index, with: book)
                } else {
                    library.addToItems(book)
                }
            }

            self.saveContext()

            DispatchQueue.main.async {
                completion()
            }
        }
    }

    class func insert(_ books: [Book], into playlist: Playlist, completion:@escaping () -> Void) {

        DispatchQueue.global().async {
            let destinationFolder = self.getProcessedFolderURL()

            for book in books {
                guard let hash = self.processFile(at: book.fileURL, destinationFolder: destinationFolder) else {
                    continue
                }

                book.identifier = hash
                book.fileURL = destinationFolder.appendingPathComponent(book.filename)

                if let index = playlist.index(of: book),
                    let storedBook = playlist.getBook(at: index) {
                    book.currentTime = storedBook.currentTime
                    playlist.replaceBooks(at: index, with: book)
                } else {
                    playlist.addToBooks(book)
                }
            }

            self.saveContext()

            DispatchQueue.main.async {
                completion()
            }
        }
    }

    class func createPlaylist(title: String, books: [Book]) -> Playlist {
        return Playlist(title: title, books: books, context: self.persistentContainer.viewContext)
    }

    class func createBook(from fileURL: URL) -> Book {
        return Book(from: fileURL, context: self.persistentContainer.viewContext)
    }

    class func exists(_ book: Book) -> Bool {
        return FileManager.default.fileExists(atPath: book.fileURL.path)
    }

    class func playerItem(from book: Book) -> AVPlayerItem {
        let asset = AVAsset(url: book.fileURL)
        return AVPlayerItem(asset: asset)
    }
}
