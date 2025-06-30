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
  ///   - query: The search query string
  ///   - perPage: Number of results per page
  /// - Returns: BooksData containing search results
  func getBooks(query: String, perPage: Int) async throws -> BooksData
}

final class HardcoverService: BPLogger, HardcoverServiceProtocol {
  private let keychain: KeychainServiceProtocol
  private let graphQL = GraphQLClient(baseURL: "https://api.hardcover.app/v1/graphql")

  private var cancellables = Set<AnyCancellable>()

  init(keychain: KeychainServiceProtocol = KeychainService()) {
    self.keychain = keychain
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

  func startTrackingLibraryUpdates(libraryService: LibraryServiceProtocol) {
    Self.logger.info("Starting to track library updates for Hardcover sync")
    libraryService.metadataUpdatePublisher
      .sink { [weak self, weak libraryService] metadata in
        guard
          let relativePath = metadata["relativePath"] as? String,
          let isFinished = metadata["isFinished"] as? Bool,
          isFinished == true
        else { return }

        Task { [weak self] in
          guard let self, let libraryService else { return }
          await self.handleBookFinished(relativePath: relativePath, in: libraryService)
        }
      }
      .store(in: &cancellables)

    libraryService.progressUpdatePublisher
      .sink { [weak self] progress in
        guard
          let relativePath = progress["relativePath"] as? String,
          let percentCompleted = progress["percentCompleted"] as? Double
        else { return }

        Task { [weak self, weak libraryService] in
          guard let self, let libraryService else { return }
          await self.handleBookStarted(
            relativePath: relativePath,
            percentCompleted: percentCompleted,
            in: libraryService
          )
        }
      }
      .store(in: &cancellables)
  }

  private func handleBookStarted(
    relativePath: String,
    percentCompleted: Double,
    in libraryService: LibraryServiceProtocol
  ) async {
    guard
      authorization != nil,
      percentCompleted > 1.0,
      let item = libraryService.getHardcoverItem(for: relativePath),
      item.status != .reading
    else { return }

    do {
      Self.logger.info("Updating Hardcover API: book \(item.id) to 'reading' status")
      _ = try await insertUserBook(
        bookID: item.id,
        statusID: Int(HardcoverItem.Status.reading.rawValue)
      )
      Self.logger.info("Successfully updated Hardcover API for book \(item.id)")

      let updatedItem = SimpleHardcoverItem(
        id: item.id,
        artworkURL: item.artworkURL,
        title: item.title,
        author: item.author,
        status: .reading
      )
      libraryService.setHardcoverItem(updatedItem, for: relativePath)
      Self.logger.info("Updated local status to 'reading' for \(relativePath)")
    } catch {
      Self.logger.error("Failed to update Hardcover status for book \(item.id): \(error)")
    }
  }

  private func handleBookFinished(relativePath: String, in libraryService: LibraryServiceProtocol) async {
    guard
      authorization != nil,
      let item = libraryService.getHardcoverItem(for: relativePath),
      item.status != .read
    else { return }

    do {
      Self.logger.info("Updating Hardcover API: book \(item.id) to 'read' status")
      _ = try await insertUserBook(
        bookID: item.id,
        statusID: Int(HardcoverItem.Status.read.rawValue)
      )
      Self.logger.info("Successfully updated Hardcover API for book \(item.id)")

      let updatedItem = SimpleHardcoverItem(
        id: item.id,
        artworkURL: item.artworkURL,
        title: item.title,
        author: item.author,
        status: .read
      )
      libraryService.setHardcoverItem(updatedItem, for: relativePath)
      Self.logger.info("Updated local status to 'read' for \(relativePath)")
    } catch {
      Self.logger.error("Failed to update Hardcover status for book \(item.id): \(error)")
    }
  }
}

extension HardcoverService {
  func getBooks(query: String, perPage: Int) async throws -> BooksData {
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

  private func insertUserBook(bookID: Int, statusID: Int) async throws -> InsertUserBookData {
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
        "status_id": statusID
      ],
      authorization: authorization,
      responseType: InsertUserBookData.self
    )
  }
}

