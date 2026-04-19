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
  private static let activeConnectionIDKey = "audiobookshelf_active_connection_id"

  private let keychainService: KeychainServiceProtocol

  var connections: [AudiobookShelfConnectionData] = []
  var connection: AudiobookShelfConnectionData? {
    if let activeConnectionID,
       let active = connections.first(where: { $0.id == activeConnectionID }) {
      return active
    }
    return connections.first
  }
  private var urlSession: URLSession

  private(set) var activeConnectionID: String? {
    get { UserDefaults.standard.string(forKey: Self.activeConnectionIDKey) }
    set { UserDefaults.standard.set(newValue, forKey: Self.activeConnectionIDKey) }
  }

  init(keychainService: KeychainServiceProtocol = KeychainService()) {
    self.keychainService = keychainService
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 15
    self.urlSession = URLSession(configuration: configuration)
  }

  func setup() {
    reloadConnections()
  }

  /// Pings the server to verify it exists and returns the server version
  public func pingServer(at absolutePath: String) async throws -> String {
    guard let url = URL(string: absolutePath) else {
      throw IntegrationError.urlMalformed(nil)
    }

    // Use the public /ping endpoint which doesn't require authentication
    let pingURL = url.appendingPathComponent("ping")
    var request = URLRequest(url: pingURL)
    request.httpMethod = "GET"
    request.timeoutInterval = 10

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
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
      throw IntegrationError.urlMalformed(nil)
    }

    let loginURL = url.appendingPathComponent("login")
    var request = URLRequest(url: loginURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let credentials = ["username": username, "password": password]
    request.httpBody = try JSONSerialization.data(withJSONObject: credentials)

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      if httpResponse.statusCode == 401 {
        throw URLError(.userAuthenticationRequired)
      }
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
    }

    // Parse response
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let user = json["user"] as? [String: Any],
      let apiToken = user["token"] as? String,
      let userID = user["id"] as? String
    else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    let connectionData = AudiobookShelfConnectionData(
      url: url,
      serverName: serverName,
      userID: userID,
      userName: username,
      apiToken: apiToken
    )

    // Deduplicate on url + userID
    connections.removeAll { $0.url == url && $0.userID == userID }
    connections.append(connectionData)
    activeConnectionID = connectionData.id
    saveConnections()
  }

  func saveSelectedLibrary(id: String?) {
    guard let activeID = connection?.id,
          let index = connections.firstIndex(where: { $0.id == activeID }) else { return }
    connections[index].selectedLibraryId = id
    saveConnections()
  }

  func activateConnection(id: String) {
    activeConnectionID = id
  }

  func deleteConnection(id: String) {
    connections.removeAll { $0.id == id }

    if activeConnectionID == id {
      activeConnectionID = connections.first?.id
    }

    if connections.isEmpty {
      do {
        try keychainService.remove(.audiobookshelfConnection)
      } catch {
        Self.logger.warning("failed to remove connection data from keychain: \(error)")
      }
    } else {
      saveConnections()
    }
  }

  func deleteConnection() {
    if let id = connection?.id {
      deleteConnection(id: id)
    }
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
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
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
    desc: Bool? = nil,
    filter: AudiobookShelfItemFilter? = nil
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
    if let filter {
      queryItems.append(URLQueryItem(name: "filter", value: filter.queryValue))
    }

    if !queryItems.isEmpty {
      urlComponents.queryItems = queryItems
    }

    guard let url = urlComponents.url else {
      throw IntegrationError.urlFromComponents(urlComponents)
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(connection.apiToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    let itemsResponse = try decoder.decode(AudiobookShelfItemsResponse.self, from: data)

    let items = itemsResponse.results.compactMap { AudiobookShelfLibraryItem(apiItem: $0) }

    return (items, itemsResponse.total)
  }

  public func fetchFilterData(in libraryId: String) async throws -> AudiobookShelfLibraryFilterData {
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }

    let url = connection.url
      .appendingPathComponent("api")
      .appendingPathComponent("libraries")
      .appendingPathComponent(libraryId)
      .appendingPathComponent("filterdata")

    var request = URLRequest(url: url)
    request.setValue("Bearer \(connection.apiToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    return try decoder.decode(AudiobookShelfLibraryFilterData.self, from: data)
  }

  public func fetchCollections(in libraryId: String) async throws -> [AudiobookShelfCollection] {
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }

    guard
      var urlComponents = URLComponents(
        url: connection.url
          .appendingPathComponent("api")
          .appendingPathComponent("libraries")
          .appendingPathComponent(libraryId)
          .appendingPathComponent("collections"),
        resolvingAgainstBaseURL: false
      )
    else {
      throw URLError(.badURL)
    }

    urlComponents.queryItems = [
      URLQueryItem(name: "minified", value: "1")
    ]

    guard let url = urlComponents.url else {
      throw IntegrationError.urlFromComponents(urlComponents)
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(connection.apiToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    let collectionsResponse = try decoder.decode(AudiobookShelfCollectionsResponse.self, from: data)
    return collectionsResponse.results
  }

  public func fetchCollection(id: String) async throws -> AudiobookShelfCollection {
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }

    let url = connection.url
      .appendingPathComponent("api")
      .appendingPathComponent("collections")
      .appendingPathComponent(id)

    var request = URLRequest(url: url)
    request.setValue("Bearer \(connection.apiToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    return try decoder.decode(AudiobookShelfCollection.self, from: data)
  }

  public func searchItems(
    in libraryId: String,
    query: String,
    limit: Int? = nil
  ) async throws -> [AudiobookShelfLibraryItem] {
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }

    guard
      var urlComponents = URLComponents(
        url: connection.url
          .appendingPathComponent("api")
          .appendingPathComponent("libraries")
          .appendingPathComponent(libraryId)
          .appendingPathComponent("search"),
        resolvingAgainstBaseURL: false
      )
    else {
      throw URLError(.badURL)
    }

    var queryItems: [URLQueryItem] = [
      URLQueryItem(name: "q", value: query)
    ]

    if let limit {
      queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
    }

    urlComponents.queryItems = queryItems

    guard let url = urlComponents.url else {
      throw IntegrationError.urlFromComponents(urlComponents)
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(connection.apiToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    let searchResponse = try decoder.decode(AudiobookShelfSearchResponse.self, from: data)

    return searchResponse.book.compactMap { AudiobookShelfLibraryItem(apiItem: $0.libraryItem) }
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
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
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

  private func reloadConnections() {
    // Try array format first
    if let storedConnections: [AudiobookShelfConnectionData] = try? keychainService.get(.audiobookshelfConnection) {
      connections = storedConnections.filter { isConnectionValid($0) }
    } else if let single: AudiobookShelfConnectionData = try? keychainService.get(.audiobookshelfConnection),
              isConnectionValid(single) {
      // Migrate from single-connection format
      connections = [single]
      saveConnections()
    } else {
      Self.logger.warning("failed to load connection data from keychain")
      return
    }

    // Normalize activeConnectionID
    if connections.isEmpty {
      activeConnectionID = nil
    } else if let activeID = activeConnectionID,
              !connections.contains(where: { $0.id == activeID }) {
      activeConnectionID = connections.first?.id
    } else if activeConnectionID == nil {
      activeConnectionID = connections.first?.id
    }
  }

  private func saveConnections() {
    try? keychainService.set(connections, key: .audiobookshelfConnection)
  }

  private func isConnectionValid(_ data: AudiobookShelfConnectionData) -> Bool {
    return !data.userID.isEmpty && !data.apiToken.isEmpty
  }

  /// Creates an image URL for a library item
  public func createItemImageURL(_ item: AudiobookShelfLibraryItem, size: CGSize) -> URL? {
    guard let connection = connection else { return nil }

    let baseURL = connection.url
    guard let itemID = item.coverItemId ?? (item.isDownloadable ? item.id : nil) else {
      return nil
    }

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
