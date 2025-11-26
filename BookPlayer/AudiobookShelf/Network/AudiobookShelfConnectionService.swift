//
//  AudiobookShelfConnectionService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

@Observable
class AudiobookShelfConnectionService: BPLogger {
  private let keychainService: KeychainServiceProtocol

  var connection: AudiobookShelfConnectionData?
  private var urlSession: URLSession

  init(keychainService: KeychainServiceProtocol = KeychainService()) {
    self.keychainService = keychainService
    self.urlSession = URLSession.shared
  }

  func setup() {
    reloadConnection()
  }

  /// Pings the server to verify it exists and returns the server version
  public func pingServer(at absolutePath: String) async throws -> String {
    guard let url = URL(string: absolutePath) else {
      throw AudiobookShelfError.urlMalformed(nil)
    }

    // Use the public /ping endpoint which doesn't require authentication
    let pingURL = url.appendingPathComponent("ping")
    var request = URLRequest(url: pingURL)
    request.httpMethod = "GET"
    request.timeoutInterval = 10

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw AudiobookShelfError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw AudiobookShelfError.unexpectedResponse(code: httpResponse.statusCode)
    }

    // Try to parse server info - /ping returns a simple success message
    // Return the server URL as the "name" since /ping doesn't return version info
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let success = json["success"] as? Bool, success
    {
      // Return a friendly server name based on the URL
      let host = url.host ?? "AudiobookShelf Server"
      return host
    }

    return "Unknown"
  }

  /// Sign into the server and store the connection data
  public func signIn(
    username: String,
    password: String,
    serverUrl: String,
    serverName: String
  ) async throws {
    guard let url = URL(string: serverUrl) else {
      throw AudiobookShelfError.urlMalformed(nil)
    }

    let loginURL = url.appendingPathComponent("login")
    var request = URLRequest(url: loginURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let credentials = ["username": username, "password": password]
    request.httpBody = try JSONSerialization.data(withJSONObject: credentials)

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw AudiobookShelfError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      if httpResponse.statusCode == 401 {
        throw URLError(.userAuthenticationRequired)
      }
      throw AudiobookShelfError.unexpectedResponse(code: httpResponse.statusCode)
    }

    // Parse response
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let user = json["user"] as? [String: Any],
      let apiToken = user["token"] as? String,
      let userID = user["id"] as? String
    else {
      throw AudiobookShelfError.unexpectedResponse(code: nil)
    }

    let connectionData = AudiobookShelfConnectionData(
      url: url,
      serverName: serverName,
      userID: userID,
      userName: username,
      apiToken: apiToken
    )

    try keychainService.set(
      connectionData,
      key: .audiobookshelfConnection
    )

    self.connection = connectionData
  }

  func deleteConnection() {
    do {
      try keychainService.remove(.audiobookshelfConnection)
    } catch {
      Self.logger.warning("failed to remove connection data from keychain: \(error)")
    }

    connection = nil
  }

  public func fetchLibraries() async throws -> [AudiobookShelfLibrary] {
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }

    let url = connection.url
      .appendingPathComponent("api")
      .appendingPathComponent("libraries")
    var request = URLRequest(url: url)
    request.setValue("Bearer \(connection.apiToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw AudiobookShelfError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw AudiobookShelfError.unexpectedResponse(code: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    let librariesResponse = try decoder.decode(AudiobookShelfLibrariesResponse.self, from: data)
    return librariesResponse.libraries
  }

  public func fetchItems(
    in libraryId: String,
    limit: Int? = nil,
    page: Int? = nil,
    sortBy: String? = "media.metadata.title",
    desc: Bool? = nil
  ) async throws -> (items: [AudiobookShelfLibraryItem], total: Int) {
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }

    guard
      var urlComponents = URLComponents(
        url: connection.url
          .appendingPathComponent("api")
          .appendingPathComponent("libraries")
          .appendingPathComponent(libraryId)
          .appendingPathComponent("items"),
        resolvingAgainstBaseURL: false
      )
    else {
      throw URLError(.badURL)
    }

    var queryItems: [URLQueryItem] = []

    if let limit {
      queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
    }
    if let page {
      queryItems.append(URLQueryItem(name: "page", value: "\(page)"))
    }
    if let sortBy {
      queryItems.append(URLQueryItem(name: "sort", value: sortBy))
      if let desc {
        queryItems.append(URLQueryItem(name: "desc", value: desc ? "1" : "0"))
      }
    }

    if !queryItems.isEmpty {
      urlComponents.queryItems = queryItems
    }

    guard let url = urlComponents.url else {
      throw AudiobookShelfError.urlFromComponents(urlComponents)
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(connection.apiToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw AudiobookShelfError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw AudiobookShelfError.unexpectedResponse(code: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    let itemsResponse = try decoder.decode(AudiobookShelfItemsResponse.self, from: data)

    let items = itemsResponse.results.compactMap { AudiobookShelfLibraryItem(apiItem: $0) }

    return (items, itemsResponse.total)
  }

  public func fetchItemDetails(for id: String) async throws -> AudiobookShelfAudiobookDetailsData {
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }

    let url = connection.url
      .appendingPathComponent("api")
      .appendingPathComponent("items")
      .appendingPathComponent(id)
      .appending(queryItems: [URLQueryItem(name: "expanded", value: "1")])

    var request = URLRequest(url: url)
    request.setValue("Bearer \(connection.apiToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw AudiobookShelfError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      if httpResponse.statusCode == 404 {
        throw URLError(.fileDoesNotExist)
      }
      throw AudiobookShelfError.unexpectedResponse(code: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    let detailsResponse = try decoder.decode(AudiobookShelfItemDetailsResponse.self, from: data)

    return AudiobookShelfAudiobookDetailsData(apiResponse: detailsResponse)
  }

  public func createItemDownloadUrl(_ item: AudiobookShelfLibraryItem) throws -> URL {
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }

    return connection.url
      .appendingPathComponent("api")
      .appendingPathComponent("items")
      .appendingPathComponent(item.id)
      .appendingPathComponent("download")
      .appending(queryItems: [URLQueryItem(name: "token", value: connection.apiToken)])
  }

  private func reloadConnection() {
    guard
      let storedConnection: AudiobookShelfConnectionData = try? keychainService.get(.audiobookshelfConnection),
      isConnectionValid(storedConnection)
    else {
      Self.logger.warning("failed to load connection data from keychain")
      return
    }

    connection = storedConnection
  }

  private func isConnectionValid(_ data: AudiobookShelfConnectionData) -> Bool {
    return !data.userID.isEmpty && !data.apiToken.isEmpty
  }

  /// Creates an image URL for a library item
  public func createItemImageURL(_ item: AudiobookShelfLibraryItem, size: CGSize) -> URL? {
    guard let connection = connection else { return nil }

    let baseURL = connection.url
    let itemID = item.id

    // AudiobookShelf image endpoint: /api/items/:id/cover
    // Optional query params: width, height, format
    var urlString = "\(baseURL.absoluteString)/api/items/\(itemID)/cover"

    // Add size parameters if needed
    let width = Int(size.width)
    let height = Int(size.height)
    urlString += "?width=\(width)&height=\(height)&format=webp"

    // Add token for authentication
    urlString += "&token=\(connection.apiToken)"

    return URL(string: urlString)
  }
}
