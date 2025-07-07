//
//  HardcoverService.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/27/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine

protocol HardcoverServiceProtocol {
  /// Authorization token for API requests
  var authorization: String? { get set }

  /// Search for books using the Hardcover API
  /// - Parameters:
  ///   - item: The library item to build search query from
  ///   - perPage: Number of results per page
  /// - Returns: BooksData containing search results
  func getBooks(for item: SimpleLibraryItem, perPage: Int) async throws -> BooksData
  
  /// Search for books using a custom search query
  /// - Parameters:
  ///   - query: The search query string
  ///   - perPage: Number of results per page
  /// - Returns: BooksData containing search results
  func searchBooks(query: String, perPage: Int) async throws -> BooksData

  /// Auto-match newly imported books with Hardcover if enabled
  /// Uses smart duplicate detection to avoid matching multiple files to the same book
  /// - Parameters:
  ///   - items: The newly imported library items (processes book items only)
  func processAutoMatch(for items: [SimpleLibraryItem]) async
  
  /// Assign a Hardcover book to a library item
  /// - Parameters:
  ///   - book: The Hardcover book to assign (nil to remove assignment)
  ///   - item: The library item to assign it to
  func assignItem(_ book: SimpleHardcoverBook?, to item: SimpleLibraryItem)
  
  /// Remove a book from the user's Hardcover library
  /// - Parameter book: The Hardcover book to remove from library
  func removeFromLibrary(_ book: SimpleHardcoverBook) async throws
}

final class HardcoverService: BPLogger, HardcoverServiceProtocol {
  private let keychain: KeychainServiceProtocol
  private let graphQL = GraphQLClient(baseURL: "https://api.hardcover.app/v1/graphql")
  private let audioMetadataService: AudioMetadataServiceProtocol
  private let libraryService: LibraryServiceProtocol

  private var cancellables = Set<AnyCancellable>()

  private var readingThreshold: Double {
    UserDefaults.sharedDefaults.object(forKey: Constants.UserDefaults.hardcoverReadingThreshold) as? Double ?? 1.0
  }

  private var autoMatchEnabled: Bool {
    UserDefaults.sharedDefaults.bool(forKey: Constants.UserDefaults.hardcoverAutoMatch)
  }

  private var autoAddWantToReadEnabled: Bool {
    UserDefaults.sharedDefaults.bool(forKey: Constants.UserDefaults.hardcoverAutoAddWantToRead)
  }

  init(
    libraryService: LibraryServiceProtocol,
    keychain: KeychainServiceProtocol = KeychainService(),
    audioMetadataService: AudioMetadataServiceProtocol = AudioMetadataService()
  ) {
    self.libraryService = libraryService
    self.keychain = keychain
    self.audioMetadataService = audioMetadataService
  }

  var authorization: String? {
    get {
      try? keychain.get(.hardcoverToken)
    }
    set {
      if let newValue = newValue, !newValue.isEmpty {
        try? self.keychain.set(newValue, key: .hardcoverToken)
      } else {
        try? self.keychain.remove(.hardcoverToken)

      }
    }
  }
}

extension HardcoverService {
  func getBooks(for item: SimpleLibraryItem, perPage: Int) async throws -> BooksData {
    let searchQuery = await buildSearchQuery(for: item)
    Self.logger.info("Using search query for '\(item.title)': '\(searchQuery)'")
    
    return try await searchBooks(query: searchQuery, perPage: perPage)
  }
  
  func searchBooks(query: String, perPage: Int) async throws -> BooksData {
    Self.logger.info("Using custom search query: '\(query)'")
    
    let queryString = """
        query GetBooks($query: String!, $per_page: Int!) {
          search(
            query: $query
            query_type: "book"
            per_page: $per_page
            page: 1,
            fields: "title,series_names,author_names,alternative_titles",
            weights: "5,3,3,1"
          ) {
            results
          }
        }
        """

    let result = try await graphQL.execute(
      query: queryString,
      variables: [
        "query": query,
        "per_page": perPage
      ],
      authorization: authorization,
      responseType: BooksData.self
    )

    return result
  }

  private func insertUserBook(bookID: Int, status: HardcoverBook.Status) async throws -> InsertUserBookData {
    let mutation = """
        mutation InsertUserBook($book_id: Int!, $status_id: Int!) {
          insert_user_book(
            object: {book_id: $book_id, status_id: $status_id}
          ) {
            id
          }
        }
        """

    return try await graphQL.execute(
      query: mutation,
      variables: [
        "book_id": bookID,
        "status_id": Int(status.rawValue)
      ],
      authorization: authorization,
      responseType: InsertUserBookData.self
    )
  }
  
  private func deleteUserBook(userBookID: Int) async throws -> DeleteUserBookData {
    let mutation = """
        mutation DeleteUserBook($id: Int!) {
          delete_user_book(id: $id) {
            book_id
          }
        }
        """

    return try await graphQL.execute(
      query: mutation,
      variables: [
        "id": userBookID
      ],
      authorization: authorization,
      responseType: DeleteUserBookData.self
    )
  }
}

extension HardcoverService {
  func startTrackingLibraryUpdates() {
    Self.logger.info("Starting to track library updates for Hardcover sync")

    libraryService.metadataUpdatePublisher
      .sink { [weak self] metadata in
        guard
          let relativePath = metadata["relativePath"] as? String,
          let isFinished = metadata["isFinished"] as? Bool,
          isFinished == true
        else { return }

        Task { [weak self] in
          guard let self else { return }
          await self.handleBookFinished(relativePath: relativePath)
        }
      }
      .store(in: &cancellables)

    libraryService.progressUpdatePublisher
      .sink { [weak self] progress in
        guard
          let relativePath = progress["relativePath"] as? String,
          let percentCompleted = progress["percentCompleted"] as? Double
        else { return }

        Task { [weak self] in
          guard let self else { return }
          await self.handleBookStarted(relativePath: relativePath, percentCompleted: percentCompleted)
        }
      }
      .store(in: &cancellables)
  }

  private func handleBookStarted(relativePath: String, percentCompleted: Double) async {
    guard
      authorization != nil,
      percentCompleted > readingThreshold,
      var item = libraryService.getHardcoverBook(for: relativePath),
      item.status < .reading
    else { return }

    do {
      Self.logger.info("Updating Hardcover API: book \(item.id) to 'reading' status")
      _ = try await insertUserBook(
        bookID: item.id,
        status: .reading
      )
      Self.logger.info("Successfully updated Hardcover API for book \(item.id)")

      item.status = .reading
      libraryService.setHardcoverBook(item, for: relativePath)
      Self.logger.info("Updated local status to 'reading' for \(relativePath)")
    } catch {
      Self.logger.error("Failed to update Hardcover status for book \(item.id): \(error)")
    }
  }

  private func handleBookFinished(relativePath: String) async {
    guard
      authorization != nil,
      var item = libraryService.getHardcoverBook(for: relativePath),
      item.status != .read
    else { return }

    do {
      Self.logger.info("Updating Hardcover API: book \(item.id) to 'read' status")
      _ = try await insertUserBook(
        bookID: item.id,
        status: .read
      )
      Self.logger.info("Successfully updated Hardcover API for book \(item.id)")

      item.status = .read
      libraryService.setHardcoverBook(item, for: relativePath)
      Self.logger.info("Updated local status to 'read' for \(relativePath)")
    } catch {
      Self.logger.error("Failed to update Hardcover status for book \(item.id): \(error)")
    }
  }

  func processAutoMatch(for items: [SimpleLibraryItem]) async {
    guard authorization != nil, autoMatchEnabled, !items.isEmpty else { return }

    Self.logger.info("Auto-matching \(items.count) new items with Hardcover")

    var potentialMatches: [(item: SimpleLibraryItem, book: SimpleHardcoverBook)] = []

    for item in items {
      do {
        let results = try await getBooks(for: item, perPage: 1)

        guard let firstMatch = results.search.results.hits.first?.document else {
          Self.logger.info("No Hardcover match found for '\(item.title)'")
          continue
        }

        let status: HardcoverBook.Status = autoAddWantToReadEnabled ? .library : .local
        let hardcoverBook = SimpleHardcoverBook(from: firstMatch, status: status)
        potentialMatches.append((item: item, book: hardcoverBook))
        Self.logger.info("Found potential match for '\(item.title)': Hardcover ID \(firstMatch.id)")
      } catch {
        Self.logger.error("Failed to search for item '\(item.title)': \(error)")
      }
    }

    var processedCount = 0

    while !potentialMatches.isEmpty {
      let match = potentialMatches.removeFirst()
      let bookID = match.book.id

      if potentialMatches.contains(where: { $0.book.id == bookID }) {
        potentialMatches.removeAll { $0.book.id == bookID }
        Self.logger.info("Detected duplicate matches for Hardcover ID \(bookID) - skipping these matches to prevent incorrect associations")
        continue
      }

      do {
        var book = match.book

        if autoAddWantToReadEnabled {
          let response = try await insertUserBook(
            bookID: bookID,
            status: .library
          )
          book.userBookID = response.insertUserBook.id
          Self.logger.info("Added '\(match.item.title)' to Hardcover Want to Read list")
        }
        
        libraryService.setHardcoverBook(book, for: match.item.relativePath)
        Self.logger.info("Auto-matched '\(match.item.title)' to Hardcover ID \(bookID)")
        processedCount += 1
      } catch {
        Self.logger.error("Failed to auto-match item '\(match.item.title)': \(error)")
      }
    }

    if processedCount != items.count {
      Self.logger.info("Auto-matched \(processedCount) items, skipped \(items.count - processedCount) due to missing or duplicate matches")
    } else {
      Self.logger.info("Auto-matched \(processedCount) items")
    }
  }
  
  func assignItem(_ book: SimpleHardcoverBook?, to item: SimpleLibraryItem) {
    if let book {
      Self.logger.info("Assigning Hardcover book \(book.id) to '\(item.title)'")

      if autoAddWantToReadEnabled, authorization != nil {
        Task {
          do {
            let response = try await insertUserBook(
              bookID: book.id,
              status: .library
            )
            Self.logger.info("Added '\(item.title)' to Hardcover Want to Read list")
            
            var updated = book
            updated.status = .library
            updated.userBookID = response.insertUserBook.id
            libraryService.setHardcoverBook(updated, for: item.relativePath)
          } catch {
            Self.logger.error("Failed to add '\(item.title)' to Hardcover Want to Read: \(error)")
            libraryService.setHardcoverBook(book, for: item.relativePath)
          }
        }
      } else {
        libraryService.setHardcoverBook(book, for: item.relativePath)
      }
    } else {
      libraryService.setHardcoverBook(nil, for: item.relativePath)
      Self.logger.info("Removed Hardcover assignment from '\(item.title)'")
    }
  }
  
  func removeFromLibrary(_ book: SimpleHardcoverBook) async throws {
    guard let userBookID = book.userBookID else {
      Self.logger.error("Cannot remove book \(book.id) from Hardcover library: no userBookID")
      return
    }
    
    Self.logger.info("Removing book \(book.id) from Hardcover library (userBookID: \(userBookID))")
    _ = try await deleteUserBook(userBookID: userBookID)
    Self.logger.info("Successfully removed book \(book.id) from Hardcover library")
  }
}

extension HardcoverService {
  private func buildSearchQuery(for item: SimpleLibraryItem) async -> String {
    switch item.type {
    case .folder, .bound:
      return await buildQueryForFolder(item)
    case .book:
      return await buildQueryForFile(item)
    }
  }

  private func buildQueryForFile(_ item: SimpleLibraryItem) async -> String {
    if let metadata = await audioMetadataService.extractMetadata(from: item.fileURL) {
      return buildSearchString(title: metadata.title, author: metadata.artist)
    }

    return buildSearchString(title: item.title, author: item.details)
  }

  private func buildQueryForFolder(_ item: SimpleLibraryItem) async -> String {
    do {
      let fileManager = FileManager.default
      let contents = try fileManager.contentsOfDirectory(at: item.fileURL, includingPropertiesForKeys: nil)

      if let firstAudioFile = contents.first, let metadata = await audioMetadataService.extractMetadata(from: firstAudioFile) {
        return buildSearchString(title: metadata.title, author: metadata.artist)
      }
    } catch {
      Self.logger.error("Failed to read folder contents for \(item.title): \(error)")
    }

    return buildSearchString(title: item.title, author: item.details)
  }

  private func buildSearchString(title: String, author: String) -> String {
    var cleaned = title

    let patterns = [
      #"(?i)\b(book|part|chapter|volume|vol\.?)\s+\d+\b"#,
      #"(?i)\b\d+\s*-\s*"#,  // "5 - Title" pattern
      #"(?i)^\d+\.\s*"#      // "5. Title" pattern
    ]

    for pattern in patterns {
      cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    cleaned = cleaned
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if author.isEmpty {
      return title
    } else {
      return "\(title), \(author)"
    }
  }

}

private extension SimpleHardcoverBook {
  init(from book: BooksData.SearchResults.SearchResponse.Hit.Book, status: HardcoverBook.Status) {
    self.init(
      id: book.id,
      artworkURL: book.image?.url.flatMap(URL.init(string:)),
      title: book.title,
      author: book.authorNames.first ?? "",
      status: status
    )
  }
}
