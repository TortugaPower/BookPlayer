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
  ///   - perPage: Number of results per page
  /// - Returns: BooksData containing search results
  func getBooks(query: String, perPage: Int) async throws -> BooksData
}

final class HardcoverService: BPLogger, HardcoverServiceProtocol {
  private let keychain: KeychainServiceProtocol
  private let graphQL = GraphQLClient(baseURL: "https://api.hardcover.app/v1/graphql")

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

