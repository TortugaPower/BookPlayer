//
//  HardcoverService.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/27/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit

protocol HardcoverServiceProtocol {
  /// Authorization token for API requests
  var authorization: String? { get set }

  /// Search for books using the Hardcover API
  /// - Parameters:
  ///   - query: The search query string
  ///   - queryType: The type of query (default: "Book")
  ///   - perPage: Number of results per page (default: 5)
  ///   - page: Page number (default: 1)
  /// - Returns: BooksData containing search results
  func getBooks(query: String, queryType: String, perPage: Int, page: Int) async throws -> BooksData

  /// Insert a user book into the system
  /// - Parameters:
  ///   - bookID: The ID of the book
  ///   - statusID: The status ID for the book
  ///   - dateAdded: The date the book was added (as string)
  ///   - editionID: The ID of the specific edition
  /// - Returns: InsertUserBookData containing the result
  func insertUserBook(
    bookID: Int,
    statusID: Int,
    dateAdded: String,
    editionID: Int
  ) async throws -> InsertUserBookData
}

final class HardcoverService: BPLogger, HardcoverServiceProtocol {
  private let keychain: KeychainServiceProtocol
  private let graphQL = GraphQLService(baseURL: "https://api.hardcover.app/v1/graphql")

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
}
