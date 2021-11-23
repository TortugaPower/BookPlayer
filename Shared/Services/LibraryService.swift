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
}
