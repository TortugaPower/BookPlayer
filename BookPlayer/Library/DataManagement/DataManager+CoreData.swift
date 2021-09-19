//
//  DataManager+CoreData.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import CoreData
import Foundation

extension DataManager {
  class func createBook(from url: URL) -> Book {
    return Book(from: url, context: self.getContext())
  }

  // This handles the Core Data objects creation from the Import operation
  // This method doesn't handle moving files on disk, only creating the core data structure for a given file tree
  class func insertItems(from files: [URL], into folder: Folder?, library: Library, processedItems: [LibraryItem]? = []) -> [LibraryItem] {
    guard !files.isEmpty else {
      DataManager.saveContext()
      return processedItems ?? []
    }

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
            guard let fileURL = item.fileURL else { continue }

            if let parent = folder.folder {
              if let parentURL = parent.fileURL {
                try FileManager.default.moveItem(
                  at: fileURL,
                  to: parentURL.appendingPathComponent(fileURL.lastPathComponent)
                )
              }
              parent.insert(item: item)
            } else {
              try FileManager.default.moveItem(
                at: fileURL,
                to: self.getProcessedFolderURL().appendingPathComponent(fileURL.lastPathComponent)
              )
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

      if let folderURL = folder.fileURL {
        if FileManager.default.fileExists(atPath: folderURL.path) {
          try FileManager.default.removeItem(at: folderURL)
        }
      }

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
        PlayerManager.shared.stop()
      }

      if let fileURL = book.fileURL {
        if FileManager.default.fileExists(atPath: fileURL.path) {
          try FileManager.default.removeItem(at: fileURL)
        }
      }
    }

    self.delete(item)
  }
}

// MARK: Bookmarks
extension DataManager {
  public class func getBookmark(of type: BookmarkType, for book: Book) -> Bookmark? {
    let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@ && type == %d", #keyPath(Bookmark.book.relativePath), book.relativePath, type.rawValue)

    return try? self.getContext().fetch(fetchRequest).first
  }

  public class func getBookmark(at time: Double, book: Book, type: BookmarkType) -> Bookmark? {
    let time = floor(time)

    let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@ && type == %d && time == %f", #keyPath(Bookmark.book.relativePath), book.relativePath, type.rawValue, floor(time))

    return try? self.getContext().fetch(fetchRequest).first
  }

  public class func createBookmark(at time: Double, book: Book, type: BookmarkType) -> Bookmark {
    if let bookmark = self.getBookmark(at: time, book: book, type: type) {
      return bookmark
    }

    let bookmark = Bookmark(with: floor(time), type: type, context: self.getContext())
    book.addToBookmarks(bookmark)

    self.saveContext()

    return bookmark
  }

  public class func addNote(_ note: String, bookmark: Bookmark) {
    bookmark.note = note
    self.saveContext()
  }

  public class func deleteBookmark(_ bookmark: Bookmark) {
    let book = bookmark.book
    book?.removeFromBookmarks(bookmark)
    self.delete(bookmark)
  }
}

// MARK: Items
extension DataManager {
  public class func getItem(with relativePath: String) -> LibraryItem? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
    fetchRequest.fetchLimit = 1

    return try? self.getContext().fetch(fetchRequest).first
  }
  public class func fetchContents(of folder: Folder, limit: Int = 30, offset: Int) -> [LibraryItem]? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), folder.relativePath)
    fetchRequest.fetchLimit = limit
    fetchRequest.fetchOffset = offset

    return try? self.getContext().fetch(fetchRequest)
  }
}
