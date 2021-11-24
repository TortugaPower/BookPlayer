//
//  LibraryService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/21/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation
import UIKit

public protocol LibraryServiceProtocol {
  func getLibrary() -> Library
  func getLibraryLastBook() throws -> Book?
  func getLibraryCurrentTheme() throws -> Theme?
  func getBook(with relativePath: String) -> Book?
  func findBooks(containing fileURL: URL) -> [Book]?
  func getOrderedBooks(limit: Int?) -> [Book]?
  func findFolder(with fileURL: URL) -> Folder?
  func findFolder(with relativePath: String) -> Folder?
  func hasLibraryLinked(item: LibraryItem) -> Bool
  func createFolder(with title: String, inside relativePath: String?, at index: Int?) throws -> Folder
}

public final class LibraryService: LibraryServiceProtocol {
  let dataManager: DataManager

  public init(dataManager: DataManager) {
    self.dataManager = dataManager
  }

  /**
   Gets the library for the App. There should be only one Library object at all times
   */
  public func getLibrary() -> Library {
    let context = self.dataManager.getContext()
    let fetch: NSFetchRequest<Library> = Library.fetchRequest()
    fetch.returnsObjectsAsFaults = false

    return (try? context.fetch(fetch).first) ?? self.createLibrary()
  }

  func createLibrary() -> Library {
    let context = self.dataManager.getContext()
    let library = Library.create(in: context)
    self.dataManager.saveContext()
    return library
  }

  public func getLibraryLastBook() throws -> Book? {
    let context = self.dataManager.getContext()
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Library")
    fetchRequest.propertiesToFetch = ["lastPlayedBook"]
    fetchRequest.resultType = .dictionaryResultType

    guard let dict = try context.fetch(fetchRequest).first as? [String: NSManagedObjectID],
          let lastPlayedBookId = dict["lastPlayedBook"] else {
      return nil
    }

    return try? context.existingObject(with: lastPlayedBookId) as? Book
  }

  public func getLibraryCurrentTheme() throws -> Theme? {
    let context = self.dataManager.getContext()
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Library")
    fetchRequest.propertiesToFetch = ["currentTheme"]
    fetchRequest.resultType = .dictionaryResultType

    guard let dict = try context.fetch(fetchRequest).first as? [String: NSManagedObjectID],
          let themeId = dict["currentTheme"] else {
            return self.dataManager.getTheme(with: "Default / Dark")
          }

    return try? context.existingObject(with: themeId) as? Theme
  }

  /**
   Gets a stored book from a relative path
   */
  public func getBook(with relativePath: String) -> Book? {
    let fetch: NSFetchRequest<Book> = Book.fetchRequest()
    fetch.predicate = NSPredicate(format: "relativePath ENDSWITH[C] %@", relativePath)
    let context = self.dataManager.getContext()

    return try? context.fetch(fetch).first
  }

  public func findBooks(containing fileURL: URL) -> [Book]? {
    let fetch: NSFetchRequest<Book> = Book.fetchRequest()
    fetch.predicate = NSPredicate(format: "relativePath ENDSWITH[C] %@", fileURL.lastPathComponent)
    let context = self.dataManager.getContext()

    return try? context.fetch(fetch)
  }

  public func getOrderedBooks(limit: Int?) -> [Book]? {
    let fetch: NSFetchRequest<Book> = Book.fetchRequest()
    fetch.predicate = NSPredicate(format: "lastPlayDate != nil")

    if let limit = limit {
      fetch.fetchLimit = limit
    }

    let sort = NSSortDescriptor(key: #keyPath(Book.lastPlayDate), ascending: false)
    fetch.sortDescriptors = [sort]

    let context = self.dataManager.getContext()

    return try? context.fetch(fetch)
  }

  // MARK: - Folders
  public func findFolder(with fileURL: URL) -> Folder? {
    return self.findFolder(
      with: String(fileURL.relativePath(to: DataManager.getProcessedFolderURL()).dropFirst())
    )
  }

  public func findFolder(with relativePath: String) -> Folder? {
    let fetch: NSFetchRequest<Folder> = Folder.fetchRequest()

    fetch.predicate = NSPredicate(format: "relativePath == %@", relativePath)

    return try? self.dataManager.getContext().fetch(fetch).first
  }

  public func hasLibraryLinked(item: LibraryItem) -> Bool {

    var keyPath = item.relativePath.split(separator: "/")
      .dropLast()
      .map({ _ in return "folder" })
      .joined(separator: ".")

    keyPath += keyPath.isEmpty ? "library" : ".library"

    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()

    fetchRequest.predicate = NSPredicate(format: "relativePath == %@ && \(keyPath) != nil", item.relativePath)

    return (try? self.dataManager.getContext().fetch(fetchRequest).first) != nil
  }

  func removeFolderIfNeeded(_ fileURL: URL) throws {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

    // Delete folder if it belongs to an orphaned folder
    if let existingFolder = self.findFolder(with: fileURL) {
      if !self.hasLibraryLinked(item: existingFolder) {
        // Delete folder if it doesn't belong to active folder
        try FileManager.default.removeItem(at: fileURL)
        self.dataManager.delete(existingFolder)
      }
    } else {
      // Delete folder if it doesn't belong to active folder
      try FileManager.default.removeItem(at: fileURL)
    }
  }

  public func createFolder(with title: String, inside relativePath: String?, at index: Int?) throws -> Folder {
    let processedFolder = DataManager.getProcessedFolderURL()
    let destinationURL: URL

    if let relativePath = relativePath {
      destinationURL = processedFolder.appendingPathComponent(relativePath).appendingPathComponent(title)
    } else {
      destinationURL = processedFolder.appendingPathComponent(title)
    }

    try? removeFolderIfNeeded(destinationURL)
    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: false, attributes: nil)

    let newFolder = Folder(title: title, context: self.dataManager.getContext())

    // insert into existing folder or library at index
    if let relativePath = relativePath {
      // The folder object must exist
      let folder = self.findFolder(with: relativePath)!
      folder.insert(item: newFolder, at: index)
    } else {
      let library = self.getLibrary()
      library.insert(item: newFolder, at: index)
    }

    self.dataManager.saveContext()

    return newFolder
  }
}
