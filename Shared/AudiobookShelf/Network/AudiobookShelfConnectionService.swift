//
//  AudiobookShelfConnectionService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

@Observable
public class AudiobookShelfConnectionService: BPLogger {
  private let keychainService: KeychainServiceProtocol

  public var connection: AudiobookShelfConnectionData?
  private var urlSession: URLSession


  public init(keychainService: KeychainServiceProtocol = KeychainService()) {
    self.keychainService = keychainService
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 15
    self.urlSession = URLSession(configuration: configuration)
  }

  public func setup() {
    reloadConnection()
  }

  /// Pings the server to verify it exists and returns the server version
  public func pingServer(
    at absolutePath: String,
    customHeaders: [String: String] = [:]
  ) async throws -> String {
    guard let url = URL(string: absolutePath) else {
      throw IntegrationError.urlMalformed(nil)
    }

    // Use the public /ping endpoint which doesn't require authentication
    let pingURL = url.appendingPathComponent("ping")
    var request = URLRequest(url: pingURL)
    request.httpMethod = "GET"
    request.timeoutInterval = 10
    applyCustomHeaders(to: &request, headers: customHeaders)

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
    serverName: String,
    customHeaders: [String: String] = [:]
  ) async throws {
    guard let url = URL(string: serverUrl) else {
      throw IntegrationError.urlMalformed(nil)
    }

    let loginURL = url.appendingPathComponent("login")
    var request = URLRequest(url: loginURL)
    request.httpMethod = "POST"
    applyCustomHeaders(to: &request, headers: customHeaders)
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
      apiToken: apiToken,
      customHeaders: customHeaders
    )

    try keychainService.set(
      connectionData,
      key: .audiobookshelfConnection
    )

    self.connection = connectionData
  }

  public func updateCustomHeaders(_ headers: [String: String]) {
    guard var data = connection else { return }
    data.customHeaders = headers
    connection = data
    try? keychainService.set(data, key: .audiobookshelfConnection)
  }

  public func saveSelectedLibrary(id: String?) {
    guard var data = connection else { return }
    data.selectedLibraryId = id
    connection = data
    try? keychainService.set(data, key: .audiobookshelfConnection)
  }

  public func deleteConnection() {
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
    applyAuthenticatedHeaders(to: &request, connection: connection)

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

    if !queryItems.isEmpty {
      urlComponents.queryItems = queryItems
    }

    // Append the filter param via `percentEncodedQuery` rather than
    // `URLQueryItem`. The filter value is `<group>.<base64>`, and base64 can
    // include `+` / `/`. `URLQueryItem` leaves both unencoded, but Express on
    // the ABS server interprets `+` in a query value as a space (form-encoding
    // convention) which silently corrupts the base64-encoded ID — typically
    // collapsing it to a 0- or 1-match. Only `+` and `/` need fixing; `=`
    // padding is already escaped by URLComponents elsewhere.
    if let filter {
      let safeValue = filter.queryValue
        .replacingOccurrences(of: "+", with: "%2B")
        .replacingOccurrences(of: "/", with: "%2F")
      let existingQuery = urlComponents.percentEncodedQuery ?? ""
      urlComponents.percentEncodedQuery = existingQuery.isEmpty
        ? "filter=\(safeValue)"
        : "\(existingQuery)&filter=\(safeValue)"
    }

    guard let url = urlComponents.url else {
      throw IntegrationError.urlFromComponents(urlComponents)
    }

    var request = URLRequest(url: url)
    applyAuthenticatedHeaders(to: &request, connection: connection)

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

  /// Fetch the books linked to a specific author via the dedicated author endpoint.
  ///
  /// The `/items?filter=authors.<base64>` route joins through the `bookAuthors`
  /// table. ABS rewrites author IDs on dedup/import, which can leave that table
  /// pointing some books at stale author IDs — the filter endpoint then returns
  /// only the one book still attached to the current ID. `/api/authors/:id?include=items`
  /// hydrates `libraryItems` from the author record itself and is what the
  /// official Vue web client uses on the author-detail page.
  public func fetchAuthorItems(authorID: String) async throws -> [AudiobookShelfLibraryItem] {
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }

    guard
      var urlComponents = URLComponents(
        url: connection.url
          .appendingPathComponent("api")
          .appendingPathComponent("authors")
          .appendingPathComponent(authorID),
        resolvingAgainstBaseURL: false
      )
    else {
      throw URLError(.badURL)
    }

    urlComponents.queryItems = [URLQueryItem(name: "include", value: "items")]

    guard let url = urlComponents.url else {
      throw IntegrationError.urlFromComponents(urlComponents)
    }

    var request = URLRequest(url: url)
    applyAuthenticatedHeaders(to: &request, connection: connection)

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    let authorResponse = try decoder.decode(AudiobookShelfAuthorWithItemsResponse.self, from: data)
    return (authorResponse.libraryItems ?? []).compactMap { AudiobookShelfLibraryItem(apiItem: $0) }
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
    applyAuthenticatedHeaders(to: &request, connection: connection)

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
    applyAuthenticatedHeaders(to: &request, connection: connection)

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
    applyAuthenticatedHeaders(to: &request, connection: connection)

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
    applyAuthenticatedHeaders(to: &request, connection: connection)

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
    applyAuthenticatedHeaders(to: &request, connection: connection)

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
  
  public func fetchItem(for id: String) async throws -> AudiobookShelfLibraryItem? {
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }

    let url = connection.url
      .appendingPathComponent("api")
      .appendingPathComponent("me")
      .appendingPathComponent("progress")
      .appendingPathComponent(id)
    
    var request = URLRequest(url: url)
    applyAuthenticatedHeaders(to: &request, connection: connection)
    let (data, response) = try await urlSession.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
    }
    let decoder = JSONDecoder()
    let detailsResponse = try decoder.decode(AudiobookShelfAPIItem.UserMediaProgress.self, from: data)
    return AudiobookShelfLibraryItem(progressItem: detailsResponse)
  }
  
  public func updateProgress(
    for id: String,
    progress: Double,
    currentTime: Double
  ) async throws {
    
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }
    
    let url = connection.url
      .appendingPathComponent("api")
      .appendingPathComponent("me")
      .appendingPathComponent("progress")
      .appendingPathComponent(id)
    
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    
    applyAuthenticatedHeaders(to: &request, connection: connection)
    
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = [
      "progress": progress,
      "currentTime": currentTime
    ]
    
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (_, response) = try await urlSession.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }
    
    guard (200...299).contains(httpResponse.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
    }
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

  /// Returns a URLRequest for downloading a library item, carrying the user-defined
  /// custom HTTP headers (needed for servers behind Cloudflare Access etc.).
  public func createItemDownloadRequest(_ item: AudiobookShelfLibraryItem) throws -> URLRequest {
    guard connection != nil else {
      throw URLError(.userAuthenticationRequired)
    }
    let url = try createItemDownloadUrl(item)
    return wrapWithCustomHeaders(url)
  }

  /// Wraps an arbitrary URL (e.g. a cover image or stream URL) in a URLRequest that carries
  /// the current connection's custom HTTP headers.
  public func wrapWithCustomHeaders(_ url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    applyCustomHeaders(to: &request, headers: connection?.customHeaders ?? [:])
    return request
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

  /// Apply user-defined custom headers (e.g. Cloudflare Access Service Tokens) to an outgoing request.
  /// Called before integration-specific headers (Authorization, Content-Type) so the integration's
  /// own values always win on conflict.
  private func applyCustomHeaders(to request: inout URLRequest, headers: [String: String]) {
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }
  }

  private func applyAuthenticatedHeaders(
    to request: inout URLRequest,
    connection: AudiobookShelfConnectionData
  ) {
    applyCustomHeaders(to: &request, headers: connection.customHeaders)
    request.setValue("Bearer \(connection.apiToken)", forHTTPHeaderField: "Authorization")
  }

  /// Creates an image URL for a library item. The API token is delivered via the
  /// `Authorization: Bearer` header — applied in the Kingfisher `requestModifier`
  /// inside `AudiobookShelfLibraryItemImageViewWrapper` — rather than in the URL,
  /// so that rotated tokens don't leave stale entries in Kingfisher's disk cache.
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

    return URL(string: urlString)
  }
}
