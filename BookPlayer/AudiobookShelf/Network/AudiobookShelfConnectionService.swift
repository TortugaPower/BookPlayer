//
//  AudiobookShelfConnectionService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AuthenticationServices
import BookPlayerKit
import CryptoKit
import Foundation
import UIKit

@MainActor
@Observable
class AudiobookShelfConnectionService: BPLogger {
  private static let activeConnectionIDKey = "audiobookshelf_active_connection_id"

  private nonisolated let keychainService: KeychainServiceProtocol

  var connections: [AudiobookShelfConnectionData] = []
  var connection: AudiobookShelfConnectionData? {
    if let activeConnectionID,
       let active = connections.first(where: { $0.id == activeConnectionID }) {
      return active
    }
    return connections.first
  }
  private let urlSession: URLSession

  /// ABS OIDC ("SSO") constants. `oidcClientID` is the app name ABS records for the session;
  /// the redirect URI uses the app's already-registered `bookplayer` URL scheme, which ABS
  /// whitelists and routes back through `/auth/openid/mobile-redirect`.
  private static let oidcClientID = "BookPlayer"
  private static let oidcRedirectURI = "bookplayer://oauth"
  private static let oidcCallbackScheme = "bookplayer"

  /// Retained for the lifetime of an in-flight web-auth flow so the system sheet isn't torn
  /// down when `signInWithOIDC` suspends on its continuation.
  private var activeWebAuthSession: ASWebAuthenticationSession?
  private let webAuthContextProvider = WebAuthPresentationProvider()

  private(set) var activeConnectionID: String? {
    get { UserDefaults.standard.string(forKey: Self.activeConnectionIDKey) }
    set { UserDefaults.standard.set(newValue, forKey: Self.activeConnectionIDKey) }
  }

  nonisolated init(keychainService: KeychainServiceProtocol = KeychainService()) {
    self.keychainService = keychainService
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 15
    self.urlSession = URLSession(configuration: configuration)
  }

  func setup() {
    reloadConnections()
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

    // `pingServer` is an unauthenticated probe (typically for Add Server). Do NOT route
    // its non-2xx responses through `validateAuthenticatedResponse`, which would mis-throw
    // `.sessionExpired(serverName: <some-other-saved-server>)` and push the user toward
    // re-authenticating an unrelated connection.
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
    // Bail out before persisting if the caller cancelled while the auth round-trip was
    // in flight (e.g. the user swiped the sheet down). Otherwise the cancelled sign-in
    // still ends up saved.
    try Task.checkCancellation()

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

    // On re-auth, preserve the existing connection's id + selectedLibraryId so the user
    // picks up exactly where they left off (same library context, same outbound references)
    // instead of being reset to a fresh record.
    let existing = connections.first {
      $0.url.canonicalDedupKey == url.canonicalDedupKey && $0.userID == userID
    }
    let connectionData = AudiobookShelfConnectionData(
      id: existing?.id ?? UUID().uuidString,
      url: url,
      serverName: serverName,
      userID: userID,
      userName: username,
      apiToken: apiToken,
      selectedLibraryId: existing?.selectedLibraryId,
      customHeaders: customHeaders
    )

    // Deduplicate on canonical-url + userID so that trailing-slash, port, and scheme-case
    // variants of the same logical server don't accumulate as separate connections.
    connections.removeAll {
      $0.url.canonicalDedupKey == url.canonicalDedupKey && $0.userID == userID
    }
    connections.append(connectionData)
    activeConnectionID = connectionData.id
    saveConnections()

    // If we just replaced a previous token for this same logical server, revoke the old
    // one server-side so it doesn't linger in ABS's token list.
    if let stale = existing, stale.apiToken != apiToken {
      revokeTokenInBackground(connection: stale)
    }
  }

  /// Sign in via AudiobookShelf's native OpenID Connect ("SSO") flow and store the connection.
  ///
  /// ABS brokers the IdP handshake itself: we hand it a PKCE `code_challenge` and our custom-
  /// scheme `redirect_uri`, it bounces the user through the provider, then redirects back to
  /// `bookplayer://oauth?code=…&state=…`. We exchange that code at `/auth/openid/callback`,
  /// which returns the same `user.token` shape the password path produces — so persistence,
  /// dedup, and re-auth all reuse the existing logic.
  ///
  /// Requires the server's OIDC config to whitelist `bookplayer://oauth` as a mobile redirect.
  public func signInWithOIDC(
    serverUrl: String,
    serverName: String,
    customHeaders: [String: String] = [:]
  ) async throws {
    guard let baseURL = URL(string: serverUrl) else {
      throw IntegrationError.urlMalformed(nil)
    }
    // Release the retained web-auth session on every exit path (success, error, cancellation).
    defer { activeWebAuthSession = nil }

    let codeVerifier = Self.makeRandomURLSafeString(byteCount: 32)
    let codeChallenge = Self.codeChallenge(for: codeVerifier)
    let state = Self.makeRandomURLSafeString(byteCount: 16)

    guard
      var authComponents = URLComponents(
        url: baseURL.appendingPathComponent("auth").appendingPathComponent("openid"),
        resolvingAgainstBaseURL: false
      )
    else {
      throw IntegrationError.urlMalformed(baseURL)
    }
    authComponents.queryItems = [
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "client_id", value: Self.oidcClientID),
      URLQueryItem(name: "redirect_uri", value: Self.oidcRedirectURI),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "state", value: state),
    ]
    guard let authURL = authComponents.url else {
      throw IntegrationError.urlFromComponents(authComponents)
    }

    let callbackURL = try await presentWebAuthSession(
      url: authURL,
      callbackScheme: Self.oidcCallbackScheme
    )
    try Task.checkCancellation()

    guard
      let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
      let returnedState = callbackComponents.queryItems?.first(where: { $0.name == "state" })?.value,
      let code = callbackComponents.queryItems?.first(where: { $0.name == "code" })?.value
    else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }
    // Reject a mismatched state — guards against a replayed or forged redirect.
    guard returnedState == state else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard
      var exchangeComponents = URLComponents(
        url: baseURL
          .appendingPathComponent("auth")
          .appendingPathComponent("openid")
          .appendingPathComponent("callback"),
        resolvingAgainstBaseURL: false
      )
    else {
      throw IntegrationError.urlMalformed(baseURL)
    }
    exchangeComponents.queryItems = [
      URLQueryItem(name: "state", value: state),
      URLQueryItem(name: "code", value: code),
      URLQueryItem(name: "code_verifier", value: codeVerifier),
    ]
    guard let exchangeURL = exchangeComponents.url else {
      throw IntegrationError.urlFromComponents(exchangeComponents)
    }

    var request = URLRequest(url: exchangeURL)
    request.httpMethod = "GET"
    applyCustomHeaders(to: &request, headers: customHeaders)

    let (data, response) = try await urlSession.data(for: request)
    try Task.checkCancellation()

    guard let httpResponse = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      if httpResponse.statusCode == 401 {
        throw URLError(.userAuthenticationRequired)
      }
      throw IntegrationError.unexpectedResponse(code: httpResponse.statusCode)
    }

    guard
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let user = json["user"] as? [String: Any],
      let apiToken = user["token"] as? String,
      let userID = user["id"] as? String
    else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }
    // ABS returns `username`; fall back to `name` / the server name so the row always has a label.
    let userName = (user["username"] as? String) ?? (user["name"] as? String) ?? serverName

    // Persist using the same dedup + re-auth-preserving logic as the password path.
    let existing = connections.first {
      $0.url.canonicalDedupKey == baseURL.canonicalDedupKey && $0.userID == userID
    }
    let connectionData = AudiobookShelfConnectionData(
      id: existing?.id ?? UUID().uuidString,
      url: baseURL,
      serverName: serverName,
      userID: userID,
      userName: userName,
      apiToken: apiToken,
      selectedLibraryId: existing?.selectedLibraryId,
      customHeaders: customHeaders
    )
    connections.removeAll {
      $0.url.canonicalDedupKey == baseURL.canonicalDedupKey && $0.userID == userID
    }
    connections.append(connectionData)
    activeConnectionID = connectionData.id
    saveConnections()

    if let stale = existing, stale.apiToken != apiToken {
      revokeTokenInBackground(connection: stale)
    }
  }

  /// Presents the system web-authentication sheet for `url` and resolves with the redirect URL
  /// once the provider bounces back to our custom scheme. User cancellation maps to
  /// `CancellationError` so the connection UI stays quiet (mirrors the in-flight-dismiss path).
  @MainActor
  private func presentWebAuthSession(url: URL, callbackScheme: String) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      let session = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: callbackScheme
      ) { callbackURL, error in
        // Cleanup of `activeWebAuthSession` happens in the caller's `defer`, so this
        // escaping completion doesn't touch MainActor-isolated state.
        if let error {
          if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
            continuation.resume(throwing: CancellationError())
          } else {
            continuation.resume(throwing: error)
          }
          return
        }
        guard let callbackURL else {
          continuation.resume(throwing: IntegrationError.unexpectedResponse(code: nil))
          return
        }
        continuation.resume(returning: callbackURL)
      }
      session.presentationContextProvider = webAuthContextProvider
      activeWebAuthSession = session
      if !session.start() {
        activeWebAuthSession = nil
        continuation.resume(throwing: IntegrationError.unexpectedResponse(code: nil))
      }
    }
  }

  /// RFC 7636 PKCE verifier: `byteCount` random bytes, base64url-encoded (no padding).
  private static func makeRandomURLSafeString(byteCount: Int) -> String {
    var generator = SystemRandomNumberGenerator()
    let bytes = (0..<byteCount).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) }
    return Data(bytes).base64URLEncodedString()
  }

  /// RFC 7636 S256 challenge: base64url(SHA256(verifier)).
  private static func codeChallenge(for verifier: String) -> String {
    let digest = SHA256.hash(data: Data(verifier.utf8))
    return Data(digest).base64URLEncodedString()
  }

  func updateCustomHeaders(_ headers: [String: String]) {
    guard let activeID = connection?.id else { return }
    updateCustomHeaders(id: activeID, headers)
  }

  /// Persist `headers` to the connection with the given id, regardless of which is active.
  func updateCustomHeaders(id: String, _ headers: [String: String]) {
    guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
    connections[index].customHeaders = headers
    saveConnections()
  }

  func saveSelectedLibrary(id: String?) {
    guard let activeID = connection?.id,
          let index = connections.firstIndex(where: { $0.id == activeID }) else { return }
    connections[index].selectedLibraryId = id
    saveConnections()
  }

  func activateConnection(id: String) {
    guard connections.contains(where: { $0.id == id }) else { return }
    activeConnectionID = id
  }

  func deleteConnection(id: String) {
    // Capture the connection BEFORE removing so we can fire a server-side logout.
    let removed = connections.first(where: { $0.id == id })

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

    if let removed {
      revokeTokenInBackground(connection: removed)
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
    applyAuthenticatedHeaders(to: &request, connection: connection)

    let (data, response) = try await urlSession.data(for: request)

    _ = try validateAuthenticatedResponse(response)

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

    _ = try validateAuthenticatedResponse(response)

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

    _ = try validateAuthenticatedResponse(response)

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

    _ = try validateAuthenticatedResponse(response)

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

    _ = try validateAuthenticatedResponse(response)

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

    _ = try validateAuthenticatedResponse(response)

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

    _ = try validateAuthenticatedResponse(response)

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

    _ = try validateAuthenticatedResponse(response)

    let decoder = JSONDecoder()
    let detailsResponse = try decoder.decode(AudiobookShelfItemDetailsResponse.self, from: data)

    return AudiobookShelfAudiobookDetailsData(apiResponse: detailsResponse)
  }

  /// Builds the download URL. The token is deliberately **not** appended as a query
  /// parameter: ABS documents `Authorization: Bearer` as the primary scheme (`?token=`
  /// is only an optional convenience for GETs), and a token-bearing URL leaks into
  /// proxy/CDN access logs and into the download task's persisted `taskDescription`.
  ///
  /// Kept private because the returned URL is *not* self-authenticating — handing it
  /// straight to `URLSession`/`AVURLAsset` would 401. Go through
  /// `createItemDownloadRequest(_:)`, which attaches the bearer.
  private func createItemDownloadUrl(
    _ item: AudiobookShelfLibraryItem,
    connection: AudiobookShelfConnectionData
  ) -> URL {
    return connection.url
      .appendingPathComponent("api")
      .appendingPathComponent("items")
      .appendingPathComponent(item.id)
      .appendingPathComponent("download")
  }

  /// Returns a URLRequest for downloading a library item, carrying the bearer
  /// token via the standard `Authorization: Bearer` header plus the user-defined
  /// custom HTTP headers (needed for servers behind Cloudflare Access etc.).
  public func createItemDownloadRequest(_ item: AudiobookShelfLibraryItem) throws -> URLRequest {
    guard let connection else {
      throw URLError(.userAuthenticationRequired)
    }
    let url = createItemDownloadUrl(item, connection: connection)
    var request = URLRequest(url: url)
    applyAuthenticatedHeaders(to: &request, connection: connection)
    return request
  }

  private func reloadConnections() {
    // Try array format first
    if let storedConnections: [AudiobookShelfConnectionData] = try? keychainService.get(.audiobookshelfConnection) {
      connections = storedConnections.filter { isConnectionValid($0) }
      if connections.count != storedConnections.count {
        saveConnections()
      }
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

  /// Fire-and-forget POST to ABS's `/logout` to revoke a connection's apiToken server-side.
  /// Called after we drop a connection locally (delete, or re-auth replacing a stale token)
  /// so the server doesn't accumulate orphan tokens. Failures are intentionally swallowed —
  /// the local state has already moved on and there's no UX-meaningful recovery.
  private func revokeTokenInBackground(connection: AudiobookShelfConnectionData) {
    let url = connection.url.appendingPathComponent("logout")
    let apiToken = connection.apiToken
    let headers = connection.customHeaders
    Task { [urlSession] in
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
      for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
      }
      _ = try? await urlSession.data(for: request)
    }
  }

  /// Validates the HTTP response from an authenticated data-fetch call.
  ///
  /// - Returns the `HTTPURLResponse` on 2xx.
  /// - Throws `IntegrationError.sessionExpired` on 401/403 **when a saved connection exists**,
  ///   so the UI can offer a Sign-In-only recovery path. Pre-sign-in probes (`pingServer`)
  ///   fall through to the generic path instead of pretending a session expired.
  /// - Throws `IntegrationError.unexpectedResponse` otherwise.
  private func validateAuthenticatedResponse(_ response: URLResponse) throws -> HTTPURLResponse {
    guard let http = response as? HTTPURLResponse else {
      throw IntegrationError.unexpectedResponse(code: nil)
    }
    if let serverName = connection?.serverName,
       http.statusCode == 401 || http.statusCode == 403 {
      throw IntegrationError.sessionExpired(serverName: serverName)
    }
    guard (200...299).contains(http.statusCode) else {
      throw IntegrationError.unexpectedResponse(code: http.statusCode)
    }
    return http
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

/// Supplies the anchor window `ASWebAuthenticationSession` presents its sheet from. Resolves
/// the foreground-active window scene's key window, falling back to any available window.
private final class WebAuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    return scene?.keyWindow ?? scene?.windows.first ?? ASPresentationAnchor()
  }
}

private extension Data {
  /// RFC 7636 base64url, no padding — used for PKCE verifier/challenge encoding.
  func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
