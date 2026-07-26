//
//  AudiobookShelfConnectionService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

@MainActor
@Observable
class AudiobookShelfConnectionService: BPLogger {
  /// `nonisolated` so the `nonisolated init` below can read it without crossing isolation.
  private nonisolated static let activeConnectionIDKey = "audiobookshelf_active_connection_id"

  /// Keychain persistence, de-duplication and active-selection bookkeeping, shared with Jellyfin.
  /// Reads below forward into it so views keep observing through this service.
  private let store: IntegrationConnectionStore<AudiobookShelfConnectionData>

  var connections: [AudiobookShelfConnectionData] { store.connections }
  var connection: AudiobookShelfConnectionData? { store.active }
  private let urlSession: URLSession

  /// Redirect-aware HTTP client for the OIDC handshake. Separate from `urlSession` because the
  /// handshake needs a client that can decline redirects *and* share one cookie jar across its two
  /// server calls — see ``AudiobookShelfOIDCFlow``.
  private nonisolated let httpClient: IntegrationHTTPClient
  /// `nonisolated` (not `nonisolated(unsafe)`) because `WebAuthenticating` is `Sendable`: the compiler
  /// checks that holding one here is safe, instead of the safety resting on a comment that a future
  /// edit could invalidate.
  private nonisolated let webAuthenticator: WebAuthenticating

  var activeConnectionID: String? { store.activeConnectionID }

  nonisolated init(
    keychainService: KeychainServiceProtocol = KeychainService(),
    httpClient: IntegrationHTTPClient = IntegrationURLSessionClient(),
    webAuthenticator: WebAuthenticating = WebAuthenticationSession(),
    defaults: UserDefaults = .standard
  ) {
    self.store = IntegrationConnectionStore(
      keychainKey: .audiobookshelfConnection,
      activeIDDefaultsKey: Self.activeConnectionIDKey,
      keychain: keychainService,
      defaults: defaults
    )
    self.httpClient = httpClient
    self.webAuthenticator = webAuthenticator
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 15
    self.urlSession = URLSession(configuration: configuration)
  }

  func setup() {
    store.reload()
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

    // Goes through the injected client, like the rest of the connect/auth path, so the whole
    // Connect → capabilities → sign-in sequence can be driven in tests without a server.
    let (data, httpResponse) = try await httpClient.data(for: request)

    // `pingServer` is an unauthenticated probe (typically for Add Server). Do NOT route
    // its non-2xx responses through `validateAuthenticatedResponse`, which would mis-throw
    // `.sessionExpired(serverName: <some-other-saved-server>)` and push the user toward
    // re-authenticating an unrelated connection.
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

  /// What a server told us it can do, so the UI only offers sign-in methods that can actually work.
  struct ServerCapabilities: Equatable {
    var supportsOIDC: Bool = false
    /// The provider button label ABS's own web UI shows, e.g. "Login with OpenId". Preferring the
    /// server's wording means a user sees the same label here as in the browser.
    var oidcButtonText: String?
  }

  /// Best-effort capability probe against `/status`.
  ///
  /// Deliberately non-throwing: a server that doesn't answer `/status`, or answers something we don't
  /// recognise, simply isn't offered SSO — the safe default. Failing the whole connect step over a
  /// capability probe would block password sign-in for no good reason.
  public func fetchCapabilities(
    at absolutePath: String,
    customHeaders: [String: String] = [:]
  ) async -> ServerCapabilities {
    guard let url = URL(string: absolutePath)?.appendingPathComponent("status") else {
      return ServerCapabilities()
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 10
    applyCustomHeaders(to: &request, headers: customHeaders)

    guard
      let (data, http) = try? await httpClient.data(for: request),
      (200...299).contains(http.statusCode),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return ServerCapabilities()
    }

    let methods = (json["authMethods"] as? [String]) ?? []
    let buttonText = (json["authFormData"] as? [String: Any])?["authOpenIDButtonText"] as? String

    return ServerCapabilities(
      supportsOIDC: methods.contains("openid"),
      oidcButtonText: buttonText?.isEmpty == false ? buttonText : nil
    )
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

    persist(
      url: url,
      serverName: serverName,
      userID: userID,
      userName: username,
      apiToken: apiToken,
      customHeaders: customHeaders
    )
  }

  /// Saves a freshly authenticated connection, whatever the sign-in method was.
  ///
  /// The store handles de-duplication on canonical-url + userID (so trailing-slash, port and
  /// scheme-case variants of one logical server don't accumulate) and carries the existing `id` +
  /// `selectedLibraryId` forward on re-auth, so the user resumes in the same library context with
  /// the same outbound references instead of getting a fresh record. Revoking a replaced token is
  /// the integration-specific part, so it stays here.
  private func persist(
    url: URL,
    serverName: String,
    userID: String,
    userName: String,
    apiToken: String,
    customHeaders: [String: String]
  ) {
    let result = store.upsert(url: url, userID: userID) { existing in
      AudiobookShelfConnectionData(
        id: existing?.id ?? UUID().uuidString,
        url: url,
        serverName: serverName,
        userID: userID,
        userName: userName,
        apiToken: apiToken,
        selectedLibraryId: existing?.selectedLibraryId,
        customHeaders: customHeaders
      )
    }

    // If we replaced a previous token for this same logical server, revoke the old one server-side
    // so it doesn't linger in ABS's token list.
    if let stale = result.replaced, stale.apiToken != apiToken {
      revokeTokenInBackground(connection: stale)
    }
  }

  /// Sign in via AudiobookShelf's native OpenID Connect ("SSO") flow and store the connection.
  ///
  /// The handshake itself lives in ``AudiobookShelfOIDCFlow`` — the hop ordering there is subtle and
  /// worth reading before changing anything. On success the flow hands back the same
  /// `user.token` shape the password path produces, so persistence, de-duplication and re-auth all
  /// reuse ``persist(url:serverName:userID:userName:apiToken:customHeaders:)``.
  public func signInWithOIDC(
    serverUrl: String,
    serverName: String,
    customHeaders: [String: String] = [:]
  ) async throws {
    guard let baseURL = URL(string: serverUrl) else {
      throw IntegrationError.urlMalformed(nil)
    }

    let flow = AudiobookShelfOIDCFlow(http: httpClient, webAuth: webAuthenticator)
    // Use a fresh browser session when this server already has a connection saved: otherwise the
    // provider's live SSO cookie signs the *existing* user straight back in, making it impossible to
    // add a second account.
    let hasExistingConnection = connections.contains {
      $0.url.canonicalDedupKey == baseURL.canonicalDedupKey
    }

    let credentials = try await flow.run(
      baseURL: baseURL,
      serverName: serverName,
      customHeaders: customHeaders,
      prefersEphemeralSession: hasExistingConnection
    )
    try Task.checkCancellation()

    persist(
      url: baseURL,
      serverName: serverName,
      userID: credentials.userID,
      userName: credentials.userName,
      apiToken: credentials.apiToken,
      customHeaders: customHeaders
    )
  }

  func updateCustomHeaders(_ headers: [String: String]) {
    guard let activeID = connection?.id else { return }
    updateCustomHeaders(id: activeID, headers)
  }

  /// Persist `headers` to the connection with the given id, regardless of which is active.
  func updateCustomHeaders(id: String, _ headers: [String: String]) {
    store.updateCustomHeaders(id: id, headers)
  }

  func saveSelectedLibrary(id: String?) {
    guard let activeID = connection?.id else { return }
    store.setSelectedLibrary(id: activeID, libraryId: id)
  }

  func activateConnection(id: String) {
    store.setActive(id: id)
  }

  func deleteConnection(id: String) {
    // Revoke the dropped connection's token server-side so ABS doesn't accumulate orphans.
    if let removed = store.remove(id: id) {
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
