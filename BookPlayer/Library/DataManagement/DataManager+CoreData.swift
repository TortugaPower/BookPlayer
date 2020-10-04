//
//  DataManager+CoreData.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

extension DataManager {
    class func createBook(from file: FileItem) -> Book {
        return Book(from: file, context: self.persistentContainer.viewContext)
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
    public class func insertBooks(from files: [FileItem], into library: Library, completion: @escaping () -> Void) {
        self.insertBooks(from: files, into: nil, or: library, completion: completion)
    }

    /**
     Creates a book for each URL and adds it to the specified playlist. A book can't be in two places at once, so it will be removed from the library if it already existed.

     - Parameter bookUrls: `Book`s will be created for each element in this array
     - Parameter playlist: `Playlist` to which the created `Book` will be added
     - Parameter completion: Closure fired after processing all the urls.
     */
    public class func insertBooks(from files: [FileItem], into playlist: Playlist, completion: @escaping () -> Void) {
        self.insertBooks(from: files, into: playlist, or: playlist.library!, completion: completion)
    }

    public class func delete(_ items: [LibraryItem], mode: DeleteMode = .deep) {
        for item in items {
            guard let playlist = item as? Playlist else {
                // swiftlint:disable force_cast
                self.delete(item as! Book, mode: mode)
                continue
            }

            self.delete(playlist, mode: mode)
        }
    }

    public class func delete(_ playlist: Playlist, mode: DeleteMode = .deep) {
        guard let library = playlist.library else { return }

        if mode == .shallow,
            let orderedSet = playlist.books {
            library.addToItems(orderedSet)
        }

        // swiftlint:disable force_cast
        for book in playlist.books?.array as! [Book] {
            guard mode == .deep else { continue }
            self.delete(book, mode: .deep)
        }

        library.removeFromItems(playlist)

        self.delete(playlist)
    }

    public class func delete(_ book: Book, mode: DeleteMode) {
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
            NotificationCenter.default.post(name: .bookDelete,
                                            object: nil,
                                            userInfo: ["book": book])
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
}
