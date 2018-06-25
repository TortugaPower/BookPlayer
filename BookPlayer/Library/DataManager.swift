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
    static let processedFolderName = "Processed"

    // MARK: - Folder URLs

    class func getDocumentsFolderURL() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    class func getProcessedFolderURL() -> URL {
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

    // MARK: - Core Data stack

    private static var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BookPlayer")

        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
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
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    // MARK: - File processing

    /**
     Get url of files in a directory

     - Parameter folder: The folder from which to get all the files urls
     - Returns: Array of file-only `URL`, directories are excluded. It returns `nil` if the folder is empty.
     */
    internal class func getFiles(from folder: URL) -> [URL]? {
        // Get reference of all the files located inside the Documents folder
        guard let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) else {
            return nil
        }

        return filterFiles(urls)
    }

    /**
     Filter out folders from file URLs.
     */
    internal class func filterFiles(_ urls: [URL]) -> [URL] {
        return urls.filter({ !$0.hasDirectoryPath })
    }

    /**
     Process file located at a specific `URL`, renames it with the hash and moves it to the specified folder. The new file maintains the extension of the original `URL`
     - Parameter origin: File original location
     - Parameter destinationFolder: File final location
     - Returns: `URL` of the file's new location. Returns `nil` if hashing fails.
     */
    class func processFile(at origin: URL, destinationFolder: URL, completion:@escaping (URL?) -> Void) {
        guard FileManager.default.fileExists(atPath: origin.path),
            let inputStream = InputStream(url: origin) else {
            completion(nil)
            return
        }

        DispatchQueue.global().async {
            inputStream.open()

            let digest = Digest(algorithm: .md5)

            while inputStream.hasBytesAvailable {
                var inputBuffer = [UInt8](repeating: 0, count: 1024)
                inputStream.read(&inputBuffer, maxLength: inputBuffer.count)
                _ = digest.update(byteArray: inputBuffer)
            }

            inputStream.close()

            let finalDigest = digest.final()

            let hash = hexString(fromArray: finalDigest)
            let ext = origin.pathExtension
            let filename = hash + ".\(ext)"
            let destinationURL = destinationFolder.appendingPathComponent(filename)

            do {
                if !FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.moveItem(at: origin, to: destinationURL)
                } else {
                    try FileManager.default.removeItem(at: origin)
                }
            } catch {
                fatalError("Fail to move file from \(origin) to \(destinationURL)")
            }

            DispatchQueue.main.async {
                completion(destinationURL)
            }
        }
    }

    /**
     Process all the files in the documents folder and move them to the 'processed' folder (specified by the DataManager).
     - Parameter completion: Closure block which returns the array of new urls of the processed files
     */
    class func notifyPendingFiles() {
        let documentsFolder = self.getDocumentsFolderURL()

        // Get reference of all the files located inside the folder
        guard let urls = self.getFiles(from: documentsFolder) else {
            return
        }

        for url in urls {
            let userInfo = ["fileURL": url]
            NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.libraryOpenURL, object: nil, userInfo: userInfo)
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
     
     - Parameter urls: `Book`s will be created for each element in this array
     - Parameter playlist: `Playlist` to which the created `Book` will be added
     - Parameter library: `Library` to which the created `Book` will be added if the parameter `playlist` is nil
     - Parameter completion: Closure fired after processing all the urls.
     */
    class func insertBooks(from urls: [URL], into playlist: Playlist?, or library: Library, completion:@escaping () -> Void) {
        DispatchQueue.global().async {
            let context = self.persistentContainer.viewContext

            for url in urls {
                // Check if book exists in the library
                guard let item = library.getItem(with: url) else {
                    let book = Book(from: url, context: context)

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

                        library.removeFromItems(storedBook)
                        playlist?.addToBooks(storedBook)

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
    }

    /**
     Creates a book for each URL and adds it to the library. A book can't be in two places at once, so it will be removed if it already existed in a playlist.
     
     - Parameter urls: `Book`s will be created for each element in this array
     - Parameter library: `Library` to which the created `Book` will be added
     - Parameter completion: Closure fired after processing all the urls.
     */
    class func insertBooks(from urls: [URL], into library: Library, completion:@escaping () -> Void) {
        self.insertBooks(from: urls, into: nil, or: library, completion: completion)
    }

    /**
     Creates a book for each URL and adds it to the specified playlist. A book can't be in two places at once, so it will be removed from the library if it already existed.
     
     - Parameter urls: `Book`s will be created for each element in this array
     - Parameter playlist: `Playlist` to which the created `Book` will be added
     - Parameter completion: Closure fired after processing all the urls.
     */
    class func insertBooks(from urls: [URL], into playlist: Playlist, completion:@escaping () -> Void) {
        self.insertBooks(from: urls, into: playlist, or: playlist.library!, completion: completion)
    }

    class func createPlaylist(title: String, books: [Book]) -> Playlist {
        return Playlist(title: title, books: books, context: self.persistentContainer.viewContext)
    }

    class func createBook(from fileURL: URL) -> Book {
        return Book(from: fileURL, context: self.persistentContainer.viewContext)
    }

    internal class func insert(_ playlist: Playlist, into library: Library) {
        library.addToItems(playlist)
        self.saveContext()
    }

    internal class func delete(_ item: NSManagedObject) {
        self.persistentContainer.viewContext.delete(item)
        self.saveContext()
    }

    class func exists(_ book: Book) -> Bool {
        return FileManager.default.fileExists(atPath: book.fileURL.path)
    }

    class func playerItem(from book: Book) -> AVPlayerItem {
        let asset = AVAsset(url: book.fileURL)
        return AVPlayerItem(asset: asset)
    }
}
