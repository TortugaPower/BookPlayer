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
  class func createBook(from url: URL) -> Book {
    return Book(from: url, context: self.getContext())
  }

  // This handles the Core Data objects creation from the Import operation
  class func insertItems(from files: [URL], into folder: Folder?, library: Library, processedItems: [LibraryItem]? = nil) -> [LibraryItem] {
    guard !files.isEmpty else { return processedItems ?? []  }

    var remainingFiles = files
    var resultingFiles = processedItems

    let nextFile = remainingFiles.removeFirst()
    let context = self.getContext()

    let libraryItem: LibraryItem

    if let attributes = try? FileManager.default.attributesOfItem(atPath: nextFile.path),
       let type = attributes[.type] as? FileAttributeType,
       type == .typeDirectory {
      let folder = Folder(from: nextFile, context: context)
      self.handleDirectory(item: nextFile, folder: folder, library: library)
      libraryItem = folder
    } else {
      libraryItem = Book(from: nextFile, context: context)
    }

    if let folder = folder {
      folder.insert(item: libraryItem)
    } else {
      library.insert(item: libraryItem)
    }

    resultingFiles?.append(libraryItem)

    return self.insertItems(from: remainingFiles, into: folder, library: library, processedItems: resultingFiles)
  }

  class func handleDirectory(item: URL, folder: Folder, library: Library) {
    let enumerator = FileManager.default.enumerator(
      at: item,
      includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      })!
    var files = [URL]()
    for case let fileURL as URL in enumerator {
      files.append(fileURL)
    }

    _ = self.insertItems(from: files, into: folder, library: library)
  }

    /**
     Creates a book for each URL and adds it to the specified folder. If no folder is specified, it will be added to the library.

     A book can't be in two places at once, so if it already existed, it will be removed from the original folder or library, and it will be added to the new one.

     - Parameter files: `Book`s will be created for each element in this array
     - Parameter folder: `Folder` to which the created `Book` will be added
     - Parameter library: `Library` to which the created `Book` will be added if the parameter `folder` is nil
     - Parameter completion: Closure fired after processing all the urls.
     */
    class func insertBooks(from files: [URL], into folder: Folder?, or library: Library, completion: @escaping () -> Void) {
        let context = self.getContext()

        for file in files.sorted(by: {$0.fileName < $1.fileName}) {
            // TODO: do something about unprocessed URLs
            // Check if item exists in the library
            guard let item = library.getItem(with: file.relativePath(to: DataManager.getProcessedFolderURL())) else {
              let book = Book(from: file, context: context)

                if let folder = folder {
                    folder.insert(item: book)
                } else {
                    library.insert(item: book)
                }

                continue
            }

            if let parent = item.folder {
                parent.removeFromItems(item)
            }

            if let folder = folder {
                library.removeFromItems(item)
                folder.insert(item: item)
            } else {
                library.insert(item: item)
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
    public class func insertBooks(from files: [URL], into library: Library, completion: @escaping () -> Void) {
        self.insertBooks(from: files, into: nil, or: library, completion: completion)
    }

    /**
     Creates a book for each URL and adds it to the specified folder. A book can't be in two places at once, so it will be removed from the library if it already existed.

     - Parameter bookUrls: `Book`s will be created for each element in this array
     - Parameter folder: `Folder` to which the created `Book` will be added
     - Parameter completion: Closure fired after processing all the urls.
     */
    public class func insertBooks(from files: [URL], into folder: Folder, completion: @escaping () -> Void) {
        self.insertBooks(from: files, into: folder, or: folder.library!, completion: completion)
    }

  public class func moveItems(_ items: [LibraryItem], into folder: Folder) throws {
    let processedFolderURL = self.getProcessedFolderURL()

    for item in items {
      try FileManager.default.moveItem(at: processedFolderURL.appendingPathComponent(item.relativePath), to: processedFolderURL.appendingPathComponent(folder.relativePath).appendingPathComponent(item.originalFileName))
      folder.insert(item: item)
    }

    folder.updateCompletionState()
    DataManager.saveContext()
  }

  public class func moveItems(_ items: [LibraryItem], into library: Library) throws {
    let processedFolderURL = self.getProcessedFolderURL()

    for item in items {
      try FileManager.default.moveItem(at: processedFolderURL.appendingPathComponent(item.relativePath), to: processedFolderURL.appendingPathComponent(item.originalFileName))
      library.insert(item: item)
    }

    DataManager.saveContext()
  }

    public class func delete(_ items: [LibraryItem], library: Library, mode: DeleteMode = .deep) throws {
        for item in items {
            guard let folder = item as? Folder else {
                // swiftlint:disable force_cast
                try self.delete(item as! Book, library: library, mode: mode)
                continue
            }

            try self.delete(folder, library: library, mode: mode)
        }
    }

    public class func delete(_ folder: Folder, library: Library, mode: DeleteMode = .deep) throws {

        if mode == .shallow,
           let items = folder.items?.array as? [LibraryItem] {
            for item in items {
                if let parent = folder.folder {
                    parent.insert(item: item)
                } else {
                    library.insert(item: item)
                }
            }
        }

        // swiftlint:disable force_cast
        for item in folder.items?.array as! [LibraryItem] {
            guard mode == .deep else { continue }
            try self.delete(item, library: library, mode: .deep)
        }

        library.removeFromItems(folder)

        self.delete(folder)
    }

  public class func delete(_ item: LibraryItem, library: Library, mode: DeleteMode) throws {
    guard mode == .deep else {
      if item.folder != nil {
        library.insert(item: item)
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

      if let fileURL = book.fileURL {
        try FileManager.default.removeItem(at: fileURL)
      }
    }

    self.delete(item)
  }
}
