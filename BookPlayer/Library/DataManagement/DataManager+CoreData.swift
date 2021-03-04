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
        return Book(from: file, context: self.getContext())
    }

    /**
     Creates a book for each URL and adds it to the specified folder. If no folder is specified, it will be added to the library.

     A book can't be in two places at once, so if it already existed, it will be removed from the original folder or library, and it will be added to the new one.

     - Parameter files: `Book`s will be created for each element in this array
     - Parameter folder: `Folder` to which the created `Book` will be added
     - Parameter library: `Library` to which the created `Book` will be added if the parameter `folder` is nil
     - Parameter completion: Closure fired after processing all the urls.
     */
    class func insertBooks(from files: [FileItem], into folder: Folder?, or library: Library, completion: @escaping () -> Void) {
        let context = self.getContext()

        for file in files.sorted(by: {$0.originalUrl.fileName < $1.originalUrl.fileName}) {
            // TODO: do something about unprocessed URLs
            guard let url = file.processedUrl else { continue }

            // Check if item exists in the library
            guard let item = library.getItem(with: url.lastPathComponent) else {
                let book = Book(from: file, context: context)

                if let folder = folder {
                    folder.addToItems(book)
                } else {
                    library.addToItems(book)
                }

                continue
            }

            guard let storedFolder = item as? Folder,
                  let storedItem = storedFolder.getItem(with: url.lastPathComponent) else {
                if let folder = folder {
                    library.removeFromItems(item)
                    folder.addToItems(item)
                }

                continue
            }

            // Handle if item already exists in the library
            storedFolder.removeFromItems(storedItem)

            if let folder = folder {
                folder.addToItems(storedItem)
            } else {
                library.addToItems(storedItem)
            }
        }

        self.saveContext()

        DispatchQueue.main.async {
            completion()
        }
    }

    /**
     Creates a book for each URL and adds it to the library. A book can't be in two places at once, so it will be removed if it already existed in a folder.

     - Parameter bookUrls: `Book`s will be created for each element in this array
     - Parameter library: `Library` to which the created `Book` will be added
     - Parameter completion: Closure fired after processing all the urls.
     */
    public class func insertBooks(from files: [FileItem], into library: Library, completion: @escaping () -> Void) {
        self.insertBooks(from: files, into: nil, or: library, completion: completion)
    }

    /**
     Creates a book for each URL and adds it to the specified folder. A book can't be in two places at once, so it will be removed from the library if it already existed.

     - Parameter bookUrls: `Book`s will be created for each element in this array
     - Parameter folder: `Folder` to which the created `Book` will be added
     - Parameter completion: Closure fired after processing all the urls.
     */
    public class func insertBooks(from files: [FileItem], into folder: Folder, completion: @escaping () -> Void) {
        self.insertBooks(from: files, into: folder, or: folder.library!, completion: completion)
    }

    public class func delete(_ items: [LibraryItem], mode: DeleteMode = .deep) {
        for item in items {
            guard let folder = item as? Folder else {
                // swiftlint:disable force_cast
                self.delete(item as! Book, mode: mode)
                continue
            }

            self.delete(folder, mode: mode)
        }
    }

    public class func delete(_ folder: Folder, mode: DeleteMode = .deep) {
        guard let library = folder.library else { return }

        if mode == .shallow,
            let orderedSet = folder.items {
            library.addToItems(orderedSet)
        }

        // swiftlint:disable force_cast
        for item in folder.items?.array as! [LibraryItem] {
            guard mode == .deep else { continue }
            self.delete(item, mode: .deep)
        }

        library.removeFromItems(folder)

        self.delete(folder)
    }

    public class func delete(_ item: LibraryItem, mode: DeleteMode) {
        guard mode == .deep else {
            if let folder = item.folder,
               let library = folder.library {
                library.addToItems(item)

                folder.removeFromItems(item)

                self.saveContext()
            }

            return
        }

        if let book = item as? Book {
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
        }

        self.delete(item)
    }
}
