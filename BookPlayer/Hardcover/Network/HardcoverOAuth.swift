//
//  HardcoverOAuth.swift
//  BookPlayer
//
//  Created by Pedro Iniguez on 10/31/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import CryptoKit
import Foundation
import Security

/// Hardcover's OAuth: authorization code + PKCE (S256), the flow its SDK uses for native apps.
/// Endpoints from `https://api.hardcover.app/.well-known/oauth-authorization-server`
enum HardcoverOAuth {
  /// The public client id of BookPlayer's "native" app at hardcover.app → Account → Developer apps.
  /// Set per build in the xcconfig's `BP_HARDCOVER_CLIENT_ID` (Xcode Cloud writes it from its
  /// environment). A public client has no secret, so the id isn't one. Read without the crashing
  /// `configurationValue(for:)`: left empty or missing, the sign-in button stays hidden and only
  /// API keys can be used
  static let clientId: String =
    (try? Bundle.main.configurationValue(for: ConfigurationKeys.hardcoverClientId.rawValue)) ?? ""

  static let authorizeURL = URL(string: "https://hardcover.app/oauth2/authorize")!
  static let tokenURL = URL(string: "https://api.hardcover.app/oauth2/token")!
  static let revokeURL = URL(string: "https://api.hardcover.app/oauth2/revoke")!
  /// The `iss` Hardcover puts on the redirect (RFC 9207)
  static let issuer = "https://api.hardcover.app"

  /// Registered on the app exactly as written: Hardcover matches redirect URIs exactly
  static let callbackScheme = "bookplayer"
  static let redirectURI = "bookplayer://hardcover/callback"

  /// Search and book lookups, adding and removing the user's books, and `me` for the account's id
  static let scopes = ["read:catalog", "read:library", "write:library", "read:me"]

  /// Refreshed when less than this is left, so clock drift or a slow request don't send an expired token
  static let refreshLeeway: TimeInterval = 60
  /// After a refresh fails without a verdict (offline, rate limited, down), the unexpired token is
  /// used for this long before trying again
  static let refreshRetryDelay: TimeInterval = 10

  static var isAvailable: Bool { !clientId.isEmpty }
}

/// One sign-in attempt: open `url`, then read the redirect with the attempt that asked for it
struct HardcoverAuthorizationAttempt {
  let url: URL
  let state: String
  let codeVerifier: String
}

enum HardcoverOAuthError: Error, Equatable {
  /// The redirect doesn't belong to this attempt: its code must never be exchanged
  case stateMismatch
  case issuerMismatch
  case missingCode
  case invalidResponse
  /// The token endpoint refused the refresh token: revoked, expired, or already spent. Only
  /// signing in again helps
  case invalidGrant
  case server(code: String, description: String?)
  case http(Int)
}

/// The tokens of a sign-in, stored as one Keychain value (`.hardcoverSession`)
struct HardcoverTokenSet: Codable, Equatable {
  /// `hc_at_…`, sent as the Bearer token. Lasts a week
  var accessToken: String
  /// `hc_rt_…`. Lasts six months and rotates on every use
  var refreshToken: String?
  /// The granted scopes, space-separated: can be fewer than asked for
  var scope: String
  var expiresAt: Date?

  init(accessToken: String, refreshToken: String?, scope: String, expiresAt: Date?) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
    self.scope = scope
    self.expiresAt = expiresAt
  }

  /// A token endpoint answer, its expiry timed from when it arrived
  init(response body: [String: Any], receivedAt: Date) throws {
    guard let accessToken = body["access_token"] as? String, !accessToken.isEmpty else {
      throw HardcoverOAuthError.invalidResponse
    }

    self.accessToken = accessToken
    self.refreshToken = (body["refresh_token"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    self.scope = body["scope"] as? String ?? ""
    self.expiresAt = (body["expires_in"] as? NSNumber).map { receivedAt.addingTimeInterval($0.doubleValue) }
  }

  /// What the app asks for that this sign-in wasn't granted: a sign-in from before a scope was
  /// added keeps its old ones through every refresh. An answer without `scope` granted what was
  /// asked (RFC 6749 §5.1)
  var missingScopes: Set<String> {
    guard !scope.isEmpty else { return [] }

    return Set(HardcoverOAuth.scopes).subtracting(scope.split(separator: " ").map(String.init))
  }

  func needsRefresh(at now: Date) -> Bool {
    guard let expiresAt else { return false }

    return expiresAt.timeIntervalSince(now) < HardcoverOAuth.refreshLeeway
  }

  func isExpired(at now: Date) -> Bool {
    guard let expiresAt else { return false }

    return expiresAt <= now
  }
}

// MARK: - Authorize request and redirect

extension HardcoverOAuth {
  /// Builds the authorize URL with a fresh PKCE verifier and `state`.
  /// `randomBytes` is injectable so tests can check the URL against the SDK's vectors
  static func makeAuthorization(
    randomBytes: (Int) -> [UInt8] = secureRandomBytes
  ) -> HardcoverAuthorizationAttempt {
    let codeVerifier = base64URL(Data(randomBytes(32)))
    let state = base64URL(Data(randomBytes(16)))

    var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "client_id", value: clientId),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
      URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
      URLQueryItem(name: "state", value: state),
      URLQueryItem(name: "code_challenge", value: codeChallenge(for: codeVerifier)),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
    ]

    return HardcoverAuthorizationAttempt(url: components.url!, state: state, codeVerifier: codeVerifier)
  }

  /// The authorization code in the redirect back to the app. `state` is checked before anything
  /// else, errors included, so a forged redirect can't pass for this attempt's
  static func authorizationCode(
    from redirect: URL,
    for attempt: HardcoverAuthorizationAttempt
  ) throws -> String {
    let queryItems = URLComponents(url: redirect, resolvingAgainstBaseURL: false)?.queryItems ?? []
    func value(_ name: String) -> String? {
      queryItems.first(where: { $0.name == name })?.value
    }

    guard value("state") == attempt.state else {
      throw HardcoverOAuthError.stateMismatch
    }

    /// An empty `iss` says nothing, so it counts as absent
    if let iss = value("iss"), !iss.isEmpty, iss != issuer {
      throw HardcoverOAuthError.issuerMismatch
    }

    if let error = value("error") {
      throw HardcoverOAuthError.server(code: error, description: value("error_description"))
    }

    guard let code = value("code"), !code.isEmpty else {
      throw HardcoverOAuthError.missingCode
    }

    return code
  }

  static func codeChallenge(for verifier: String) -> String {
    base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
  }

  static func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  static func secureRandomBytes(_ count: Int) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: count)
    let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
    precondition(status == errSecSuccess, "No secure random bytes for the Hardcover sign-in")
    return bytes
  }

  /// `application/x-www-form-urlencoded`, every value escaped down to the unreserved characters
  static func formEncode(_ params: [String: String]) -> String {
    let unreserved = CharacterSet(
      charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    return params
      .sorted { $0.key < $1.key }
      .map { key, value in
        "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "")"
      }
      .joined(separator: "&")
  }

  static func formRequest(url: URL, _ params: [String: String]) -> URLRequest {
    var body = params
    body["client_id"] = clientId

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = Data(formEncode(body).utf8)
    return request
  }
}

// MARK: - Session

/// Owns the OAuth tokens in the Keychain and hands out a usable access token.
/// Refreshes run one at a time: a refresh token works once, and sending a spent one again revokes
/// the whole sign-in. Token requests are never retried for the same reason
actor HardcoverOAuthSession {
  typealias Send = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  private let keychain: KeychainServiceProtocol
  private let send: Send
  private let now: @Sendable () -> Date

  private var refreshTask: Task<HardcoverTokenSet, Error>?
  private var lastFailedRefresh: Date?

  init(
    keychain: KeychainServiceProtocol,
    send: @escaping Send = { try await URLSession.shared.data(for: $0) },
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.keychain = keychain
    self.send = send
    self.now = now
  }

  nonisolated var tokens: HardcoverTokenSet? {
    let tokens: HardcoverTokenSet? = try? keychain.get(.hardcoverSession)
    return tokens
  }

  nonisolated var isSignedIn: Bool { tokens != nil }

  /// The access token to send, refreshed first when it's about to expire. Nil when not signed in.
  /// - Parameter rejected: a token the API just refused. It's refreshed even with time left,
  ///   unless a refresh already replaced it
  func accessToken(replacing rejected: String? = nil) async throws -> String? {
    if let refreshTask {
      return try await refreshTask.value.accessToken
    }

    guard let current = tokens else { return nil }

    let mustRefresh: Bool
    if let rejected {
      mustRefresh = rejected == current.accessToken
    } else {
      mustRefresh = current.needsRefresh(at: now()) && !isWaitingAfterFailedRefresh(current)
    }

    guard mustRefresh, let refreshToken = current.refreshToken else {
      return current.accessToken
    }

    let task = Task { try await self.refresh(current, using: refreshToken) }
    refreshTask = task
    defer { refreshTask = nil }

    return try await task.value.accessToken
  }

  /// Exchanges the code from the redirect and stores the new sign-in
  @discardableResult
  func signIn(code: String, codeVerifier: String) async throws -> HardcoverTokenSet {
    let tokens = try await requestTokens([
      "grant_type": "authorization_code",
      "code": code,
      "code_verifier": codeVerifier,
      "redirect_uri": HardcoverOAuth.redirectURI,
    ])

    refreshTask?.cancel()
    refreshTask = nil
    lastFailedRefresh = nil
    try keychain.set(tokens, key: .hardcoverSession)
    return tokens
  }

  /// Forgets the sign-in, then revokes it. Revoking either token revokes both, and the endpoint
  /// always answers 200, so a failure only leaves a token nobody holds
  func signOut() async {
    guard let tokens else { return }

    refreshTask?.cancel()
    refreshTask = nil
    lastFailedRefresh = nil
    try? keychain.remove(.hardcoverSession)

    let request = HardcoverOAuth.formRequest(
      url: HardcoverOAuth.revokeURL,
      ["token": tokens.refreshToken ?? tokens.accessToken]
    )
    _ = try? await send(request)
  }

  private func refresh(_ current: HardcoverTokenSet, using refreshToken: String) async throws -> HardcoverTokenSet {
    do {
      let refreshed = try await requestTokens([
        "grant_type": "refresh_token",
        "refresh_token": refreshToken,
      ])

      /// Signed out, or signed in again, while it ran: the answer belongs to a sign-in that's gone
      guard tokens?.refreshToken == refreshToken else {
        throw CancellationError()
      }

      /// Stored before anything else: the old refresh token is spent now
      try keychain.set(refreshed, key: .hardcoverSession)
      lastFailedRefresh = nil
      return refreshed
    } catch HardcoverOAuthError.invalidGrant {
      if tokens?.refreshToken == refreshToken {
        try? keychain.remove(.hardcoverSession)
      }
      throw HardcoverOAuthError.invalidGrant
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      lastFailedRefresh = now()

      /// Offline, rate limited or down: the access token may still have time left
      if !current.isExpired(at: now()) {
        return current
      }
      throw error
    }
  }

  private func isWaitingAfterFailedRefresh(_ current: HardcoverTokenSet) -> Bool {
    guard
      let lastFailedRefresh,
      !current.isExpired(at: now())
    else { return false }

    return now().timeIntervalSince(lastFailedRefresh) < HardcoverOAuth.refreshRetryDelay
  }

  private func requestTokens(_ params: [String: String]) async throws -> HardcoverTokenSet {
    let request = HardcoverOAuth.formRequest(url: HardcoverOAuth.tokenURL, params)
    let (data, response) = try await send(request)

    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    let body = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]

    guard (200...299).contains(status) else {
      if let error = body["error"] as? String {
        if error == "invalid_grant" {
          throw HardcoverOAuthError.invalidGrant
        }
        throw HardcoverOAuthError.server(code: error, description: body["error_description"] as? String)
      }
      throw HardcoverOAuthError.http(status)
    }

    return try HardcoverTokenSet(response: body, receivedAt: now())
  }
}
