//
//  AudiobookShelfOIDCFlow.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 25/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

/// AudiobookShelf's native OpenID Connect ("SSO") handshake.
///
/// ABS brokers the identity-provider exchange itself, but the hop order matters and the obvious
/// shortcut doesn't work:
///
/// 1. **The app** requests `/auth/openid` *without following the redirect*. ABS answers `302` with a
///    `connect.sid` session cookie plus `auth_method=openid-mobile`, and a `Location` pointing at the
///    identity provider. Those cookies have to land in the app's own cookie jar.
/// 2. Only the identity-provider URL is handed to the browser. The provider returns to ABS's own
///    `/auth/openid/mobile-redirect`, which bounces to `audiobookshelf://oauth?code=…&state=…`, where
///    the web-auth session intercepts it.
/// 3. **The app** exchanges the code at `/auth/openid/callback` over the *same* HTTP client, so the
///    cookie from step 1 is attached — ABS validates the exchange against that session.
///
/// Opening `/auth/openid` in the browser instead leaves `connect.sid` in Safari's cookie store, and
/// step 3 then fails with `No session` against every server. That is why this flow needs an HTTP
/// client that can decline redirects, and why steps 1 and 3 must share one client.
///
/// Custom headers and proxies: user-defined headers (Cloudflare Access service tokens and similar) are
/// applied to steps 1 and 3, the requests the app makes itself. They cannot be injected into the
/// browser leg — `ASWebAuthenticationSession` accepts only `X-`-prefixed additional headers, and only
/// on the *initial* URL, which is the provider's, not the server's.
///
/// That matters less than it sounds. The only proxied request in the browser leg is step 2's bounce
/// back through the server's own `/auth/openid/mobile-redirect`; the authorize page itself belongs to
/// the identity provider, which usually isn't behind the same proxy. An *interactive* proxy handles
/// that bounce on its own — Cloudflare Access sees a browser, serves its login page and sets
/// `CF_Authorization` inside the sheet, with no cooperation from the app. Verified working end to end
/// against ABS 2.25.1 behind Access.
///
/// SSO is genuinely impossible only when the proxy offers no browser-side authentication path at all:
/// a service-token-only Access policy, or a hand-rolled header-only gate. That fails on first connect,
/// not just re-auth. And it fails *silently*: the bounce 403s, `audiobookshelf://oauth` is never
/// reached, and the user's eventual dismissal arrives as `canceledLogin` — indistinguishable from a
/// deliberate cancel, because `ASWebAuthenticationSession` reports nothing but a callback URL or one of
/// three cancel/presentation errors. There is no API to detect the 403, so this cannot be improved
/// without giving up the system browser.
///
/// Diagnostics: every failure point logs to the `Logger` subsystem (the bundle identifier) under the
/// category `AudiobookShelfOIDCFlow`, so a handshake can be traced in Console.app by filtering on that
/// category. Values are marked `.public` deliberately — `Logger` would otherwise print `<private>` and
/// tell you nothing — so only non-sensitive facts are logged: parameter *names*, presence flags,
/// lengths, status codes and JSON keys. The authorization code, the PKCE verifier and the returned
/// token are never logged.
struct AudiobookShelfOIDCFlow: BPLogger {
  /// What the handshake yields. The caller persists it exactly as it would a password sign-in.
  struct Credentials {
    let userID: String
    let userName: String
    let apiToken: String
  }

  /// ABS ships exactly one entry in `authOpenIDMobileRedirectURIs` and this is it, so SSO works
  /// against a default install with no server-side configuration. Using AudiobookShelf's scheme is
  /// safe even when the official app is installed: `ASWebAuthenticationSession` intercepts the
  /// callback inside its own session before the system ever routes the URL, so there is no contest
  /// over the scheme and no `Info.plist` registration needed.
  static let redirectURI = "audiobookshelf://oauth"
  static let callbackScheme = "audiobookshelf"

  let http: IntegrationHTTPClient
  let webAuth: WebAuthenticating

  func run(
    baseURL: URL,
    serverName: String,
    customHeaders: [String: String],
    prefersEphemeralSession: Bool
  ) async throws -> Credentials {
    // The authorization code, the PKCE verifier and the returned token all traverse the redirect
    // chain, so plaintext is not acceptable here even though password sign-in tolerates it.
    guard baseURL.scheme?.lowercased() == "https" else {
      throw IntegrationError.insecureTransport
    }

    let pkce = PKCE()
    let state = PKCE.makeState()

    let identityProviderURL = try await authorizationURL(
      baseURL: baseURL,
      pkce: pkce,
      state: state,
      customHeaders: customHeaders
    )

    let callbackURL = try await webAuth.authenticate(
      url: identityProviderURL,
      callbackScheme: Self.callbackScheme,
      prefersEphemeralSession: prefersEphemeralSession
    )
    try Task.checkCancellation()

    let code = try Self.authorizationCode(
      from: callbackURL,
      expectedState: state,
      providerCallbackURL: Self.providerCallbackURL(for: baseURL)
    )

    return try await exchange(
      baseURL: baseURL,
      serverName: serverName,
      code: code,
      state: state,
      verifier: pkce.verifier,
      customHeaders: customHeaders
    )
  }

  // MARK: - Step 1

  /// Asks ABS to start the handshake and returns the identity-provider URL it points us at, keeping
  /// the session cookies it sets on our own client.
  private func authorizationURL(
    baseURL: URL,
    pkce: PKCE,
    state: String,
    customHeaders: [String: String]
  ) async throws -> URL {
    guard
      var components = URLComponents(
        url: baseURL.appendingPathComponent("auth").appendingPathComponent("openid"),
        resolvingAgainstBaseURL: false
      )
    else {
      throw IntegrationError.urlMalformed(baseURL)
    }

    // `client_id` is deliberately absent: ABS builds the provider request from its own
    // `authOpenIDClientID` server setting and ignores whatever a client sends.
    components.queryItems = [
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
      URLQueryItem(name: "code_challenge", value: pkce.challenge),
      URLQueryItem(name: "code_challenge_method", value: PKCE.challengeMethod),
      URLQueryItem(name: "state", value: state),
    ]
    guard let url = components.url else {
      throw IntegrationError.urlFromComponents(components)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    Self.apply(customHeaders, to: &request)

    let identityProviderURL = try await http.redirectLocation(for: request)
    let items = URLComponents(url: identityProviderURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
    // Log the two values a misconfigured provider usually trips over — the redirect URI it must allow
    // and the scopes it must grant. Neither is a secret, and both are chosen by the *server*, not us,
    // so they're the first things to check when the provider refuses.
    Self.logger.info(
      """
      OIDC authorize redirect -> \
      host=\(identityProviderURL.host ?? "nil", privacy: .public) \
      port=\(identityProviderURL.port.map(String.init) ?? "default", privacy: .public) \
      path=\(identityProviderURL.path, privacy: .public) \
      params=\(items.map(\.name).sorted().joined(separator: ","), privacy: .public) \
      redirect_uri=\(items.first { $0.name == "redirect_uri" }?.value ?? "nil", privacy: .public) \
      scope=\(items.first { $0.name == "scope" }?.value ?? "nil", privacy: .public)
      """
    )
    return identityProviderURL
  }

  // MARK: - Step 2 parsing

  /// Pulls the authorization code out of the provider's callback, rejecting anything that doesn't
  /// belong to this handshake. `static` so it can be tested without a client or a browser.
  /// The URI the identity provider must be configured to allow. AudiobookShelf points the provider at
  /// its own mobile-redirect route, *not* at our custom scheme, so this is what an admin has to
  /// whitelist on the provider side.
  static func providerCallbackURL(for baseURL: URL) -> String {
    baseURL
      .appendingPathComponent("auth")
      .appendingPathComponent("openid")
      .appendingPathComponent("mobile-redirect")
      .absoluteString
  }

  static func authorizationCode(
    from callbackURL: URL,
    expectedState: String,
    providerCallbackURL: String = ""
  ) throws -> String {
    let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
    func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

    // Parameter names only — enough to tell "the server sent nothing" from "the server sent a shape we
    // don't handle" without putting the code in a log.
    Self.logger.info(
      "OIDC callback received: scheme=\(callbackURL.scheme ?? "nil", privacy: .public) host=\(callbackURL.host ?? "nil", privacy: .public) params=\(items.map(\.name).sorted().joined(separator: ","), privacy: .public)"
    )

    // Check for a provider error *before* validating state. When the user denies consent, ABS still
    // redirects with a valid state and the literal string `code=undefined`, so a state-first check
    // would pass and we'd exchange nonsense for an opaque failure.
    if let error = value("error") {
      let description = value("error_description") ?? error
      Self.logger.error("OIDC callback carried an error: \(description, privacy: .public)")
      throw IntegrationError.serverMessage(code: 400, message: description)
    }

    // Binds the callback to the request we made; a replayed or forged redirect won't match.
    guard let returnedState = value("state") else {
      Self.logger.error("OIDC callback had no state parameter — cannot bind it to this handshake")
      throw IntegrationError.unexpectedResponse(code: nil)
    }
    guard returnedState == expectedState else {
      // Lengths only: state isn't secret, but there's no reason to print nonces either.
      Self.logger.error(
        "OIDC state mismatch (returned \(returnedState.count, privacy: .public) chars, expected \(expectedState.count, privacy: .public))"
      )
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    guard let code = value("code"), !code.isEmpty, code != "undefined" else {
      // `undefined` specifically means AudiobookShelf received no `code` from the provider and
      // interpolated a missing value — its mobile-redirect handler drops the provider's own error, so
      // this is the most the app can know. Check the provider's log for the real reason; a group/access
      // restriction on the client is the usual cause, a disallowed redirect URI the next.
      Self.logger.error(
        "OIDC callback had no usable code (present=\(value("code") != nil, privacy: .public), value=\(value("code") == "undefined" ? "undefined" : "empty-or-missing", privacy: .public)); the provider denied the request — check its client restrictions and that it allows \(providerCallbackURL, privacy: .public)"
      )
      throw IntegrationError.ssoNoAuthorizationCode(providerCallbackURL: providerCallbackURL)
    }
    return code
  }

  // MARK: - Step 3

  private func exchange(
    baseURL: URL,
    serverName: String,
    code: String,
    state: String,
    verifier: String,
    customHeaders: [String: String]
  ) async throws -> Credentials {
    guard
      var components = URLComponents(
        url: baseURL
          .appendingPathComponent("auth")
          .appendingPathComponent("openid")
          .appendingPathComponent("callback"),
        resolvingAgainstBaseURL: false
      )
    else {
      throw IntegrationError.urlMalformed(baseURL)
    }

    // ABS registers this endpoint as GET only and reads `code_verifier` off the query string, so
    // these can't be moved into a request body. Both values are single-use and PKCE-bound, and
    // `AppDelegate` scrubs `http.query` out of Sentry so they don't reach telemetry.
    components.queryItems = [
      URLQueryItem(name: "state", value: state),
      URLQueryItem(name: "code", value: code),
      URLQueryItem(name: "code_verifier", value: verifier),
    ]
    guard let url = components.url else {
      throw IntegrationError.urlFromComponents(components)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    Self.apply(customHeaders, to: &request)

    let (data, response) = try await http.data(for: request)
    // Don't persist a connection the user has already walked away from.
    try Task.checkCancellation()

    guard (200...299).contains(response.statusCode) else {
      Self.logger.error(
        "OIDC exchange failed: status=\(response.statusCode, privacy: .public) bodyBytes=\(data.count, privacy: .public)"
      )
      // Deliberately *not* mapped to `URLError(.userAuthenticationRequired)` like the password path
      // does. A 401 here doesn't mean "your credentials expired, sign in again" — the identity provider
      // already authenticated the user successfully. It means AudiobookShelf refused to map that
      // identity to one of its own accounts: no matching user with auto-register disabled, a missing
      // configured group claim, or a deactivated user. ABS answers `Unauthorized` in the body, and
      // showing that beats a re-auth prompt the user can't act on.
      throw IntegrationError.from(status: response.statusCode, body: data)
    }

    // Same `user.token` shape the password path returns, so persistence is shared.
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      Self.logger.error(
        "OIDC exchange returned a 200 that isn't a JSON object (bodyBytes=\(data.count, privacy: .public))"
      )
      throw IntegrationError.unexpectedResponse(code: nil)
    }
    guard let user = json["user"] as? [String: Any] else {
      // Keys only — the payload itself contains the token.
      Self.logger.error(
        "OIDC exchange payload had no `user` object (topLevelKeys=\(json.keys.sorted().joined(separator: ","), privacy: .public))"
      )
      throw IntegrationError.unexpectedResponse(code: nil)
    }
    guard
      let apiToken = user["token"] as? String,
      let userID = user["id"] as? String
    else {
      Self.logger.error(
        "OIDC exchange `user` object lacked token/id (userKeys=\(user.keys.sorted().joined(separator: ","), privacy: .public))"
      )
      throw IntegrationError.unexpectedResponse(code: nil)
    }

    // ABS returns `username`; fall back to `name` / the server name so the row always has a label.
    let userName = (user["username"] as? String) ?? (user["name"] as? String) ?? serverName

    Self.logger.info("OIDC exchange succeeded, connection credentials obtained")
    return Credentials(userID: userID, userName: userName, apiToken: apiToken)
  }

  private static func apply(_ headers: [String: String], to request: inout URLRequest) {
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }
  }
}
