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
  func createBook(from url: URL) -> Book {
    return Book(from: url, context: self.getContext())
  }

  class func getLibraryFiles() -> [URL] {
    let enumerator = FileManager.default.enumerator(
      at: DataManager.getProcessedFolderURL(),
      includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      })!
    var files = [URL]()
    for case let fileURL as URL in enumerator {
      files.append(fileURL)
    }

    return files
  }

  // This handles the Core Data objects creation from the Import operation
  // This method doesn't handle moving files on disk, only creating the core data structure for a given file tree
  func insertItems(from files: [URL], into folder: Folder?, library: Library, processedItems: [LibraryItem]? = []) -> [LibraryItem] {
    guard !files.isEmpty else {
      self.saveContext()
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

  func handleDirectory(item: URL, folder: Folder, library: Library) {
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

  public func moveItems(_ items: [LibraryItem], into folder: Folder, at index: Int? = nil) throws {
    let processedFolderURL = DataManager.getProcessedFolderURL()

    for item in items {
      try FileManager.default.moveItem(at: processedFolderURL.appendingPathComponent(item.relativePath), to: processedFolderURL.appendingPathComponent(folder.relativePath).appendingPathComponent(item.originalFileName))
      folder.insert(item: item, at: index)
    }

    folder.updateCompletionState()
    self.saveContext()
  }

  public func moveItems(_ items: [LibraryItem],
                        into library: Library,
                        moveFiles: Bool = true,
                        at index: Int? = nil) throws {
    let processedFolderURL = DataManager.getProcessedFolderURL()

    for item in items {
      if moveFiles {
        try FileManager.default.moveItem(at: processedFolderURL.appendingPathComponent(item.relativePath), to: processedFolderURL.appendingPathComponent(item.originalFileName))
      }
      library.insert(item: item, at: index)
    }

    self.saveContext()
  }

    public func delete(_ items: [LibraryItem], library: Library, mode: DeleteMode = .deep) throws {
        for item in items {
            guard let folder = item as? Folder else {
              // swiftlint:disable force_cast
              try self.delete(item as! Book, library: library, mode: mode)
              // swiftlint:enable force_cast
              continue
            }

            try self.delete(folder, library: library, mode: mode)
        }
    }

    public func delete(_ folder: Folder, library: Library, mode: DeleteMode = .deep) throws {

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
                to: DataManager.getProcessedFolderURL().appendingPathComponent(fileURL.lastPathComponent)
              )
              library.insert(item: item)
            }
          }
        }

        // swiftlint:disable force_cast
        for item in folder.items?.array as! [LibraryItem] {
          // swiftlint:enable force_cast
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

  public func delete(_ item: LibraryItem, library: Library, mode: DeleteMode) throws {
    guard mode == .deep else {
      if item.folder != nil {
        library.insert(item: item)
        self.saveContext()
      }

      return
    }

    if let book = item as? Book {
      if let fileURL = book.fileURL {
        if FileManager.default.fileExists(atPath: fileURL.path) {
          try FileManager.default.removeItem(at: fileURL)
        }
      }
    }

    self.delete(item)
  }
}

// MARK: Items
extension DataManager {
  public func renameItem(_ item: LibraryItem, with newTitle: String) {
    item.title = newTitle

    self.saveContext()
  }
}
