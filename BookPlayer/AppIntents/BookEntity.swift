//
//  BookEntity.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/6/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AppIntents
import BookPlayerKit
import Foundation

/// Represents a book in the library that can be selected as a parameter in
/// the Shortcuts app and resolved by Siri when playing a specific book.
@available(macOS 14.0, watchOS 10.0, *)
struct BookEntity: AppEntity, Identifiable {
  /// The book's `relativePath`, used everywhere as its unique identifier.
  let id: String
  let title: String
  let details: String

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "book_title"

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "\(title)",
      subtitle: details.isEmpty ? nil : "\(details)"
    )
  }

  static var defaultQuery = BookEntityQuery()

  init(id: String, title: String, details: String) {
    self.id = id
    self.title = title
    self.details = details
  }

  init(item: SimpleLibraryItem) {
    self.id = item.relativePath
    self.title = item.title
    self.details = item.details
  }
}

/// Backs `BookEntity` selection: resolves identifiers, provides suggestions for
/// the picker, and matches spoken/typed titles for Siri.
@available(macOS 14.0, watchOS 10.0, *)
struct BookEntityQuery: EntityStringQuery {
  /// Resolve specific books by their `relativePath` identifiers.
  func entities(for identifiers: [String]) async throws -> [BookEntity] {
    let coreServices = try await AppServices.shared.awaitCoreServices()
    let libraryService = coreServices.libraryService

    return identifiers.compactMap { identifier in
      libraryService.getSimpleItem(with: identifier).map(BookEntity.init(item:))
    }
  }

  /// Match books by a typed/spoken query (title or author), powering Siri resolution.
  func entities(matching string: String) async throws -> [BookEntity] {
    let coreServices = try await AppServices.shared.awaitCoreServices()
    let items = coreServices.libraryService.searchAllBooks(
      query: string,
      limit: 50,
      offset: nil
    ) ?? []

    return items.map(BookEntity.init(item:))
  }

  /// Suggestions shown in the Shortcuts picker: most recently played books first.
  func suggestedEntities() async throws -> [BookEntity] {
    let coreServices = try await AppServices.shared.awaitCoreServices()
    let items = coreServices.libraryService.getLastPlayedItems(limit: 20) ?? []

    return items.map(BookEntity.init(item:))
  }
}
