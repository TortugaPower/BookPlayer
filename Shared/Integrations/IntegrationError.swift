//
//  IntegrationError.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// `Equatable` is synthesized (every associated value already is) so tests can assert on a specific
/// case instead of pattern-matching in every expectation.
public enum IntegrationError: Error, LocalizedError, Equatable {
  case urlMalformed(_ url: URL?)
  case urlFromComponents(_ components: URLComponents)
  case noClient(_ integrationName: String)
  case unexpectedResponse(code: Int?)
  case clientError(code: Int)
  /// The server rejected our credentials mid-session (401/403 from a non-sign-in call). Carries
  /// the offending connection's server name so the UI can prompt "Sign in again to {name}"
  /// instead of showing the generic add-server form. The view layer special-cases this so the
  /// existing connection (URL, custom headers, selected library) is preserved across re-auth.
  case sessionExpired(serverName: String)
  /// The server rejected a request with a human-readable reason in the body, surfaced verbatim
  /// because the generic status-code text hides what actually went wrong. AudiobookShelf's OIDC
  /// endpoints answer this way — e.g. `Invalid redirect_uri` when the server hasn't whitelisted our
  /// callback, or `No session` when the handshake was started outside the app.
  case serverMessage(code: Int, message: String)
  /// SSO was attempted against a plaintext `http://` server. The authorization code, the PKCE
  /// verifier and the returned token all traverse the redirect chain, so RFC 6749 §10.9 requires
  /// TLS. Password sign-in over http remains the user's own call; a redirect-based flow is a
  /// materially worse exposure.
  case insecureTransport
  /// The identity provider came back without an authorization code.
  ///
  /// AudiobookShelf's `/auth/openid/mobile-redirect` handler reads `req.query.code` and interpolates it
  /// with no null check, discarding whatever `error` / `error_description` the provider sent — so it
  /// forwards the literal string `undefined`, and the provider's actual reason is unrecoverable from
  /// the app. Only the provider's own log has it.
  ///
  /// Observed causes, in rough order of likelihood: a **group or access restriction** on the provider's
  /// client (the user authenticates, then the request is denied), and the redirect URI not being
  /// allowed. Both are named in the message because the app cannot tell them apart.
  ///
  /// Caveat when reading that message: `providerCallbackURL` is what the app *derives* from the server
  /// URL, and is always `https` because the flow refuses plaintext. The server builds its own — so a
  /// proxy that fails to forward `X-Forwarded-Proto: https` makes AudiobookShelf send an `http://`
  /// redirect URI the provider then rejects as unregistered, while the message still shows `https` and
  /// looks like a match. The `redirect_uri=` value in the authorize log line is the authoritative one.
  case ssoNoAuthorizationCode(providerCallbackURL: String)

  /// Builds the most useful error available for a failed response: the server's own message when the
  /// body is a short human-readable string, otherwise the bare status code. AudiobookShelf's auth
  /// endpoints answer in plain text, and those messages are the difference between "unexpected
  /// response 400" and "Invalid redirect_uri".
  public static func from(status: Int, body: Data) -> IntegrationError {
    guard
      let text = String(data: body, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !text.isEmpty,
      // Don't dump an HTML error page into an alert.
      text.count <= 200,
      !text.hasPrefix("<")
    else {
      return .unexpectedResponse(code: status)
    }
    return .serverMessage(code: status, message: text)
  }

  /// True when the error is a recoverable re-auth case — the UI should offer a Sign-In-only
  /// recovery path that preserves the existing connection instead of treating it as a generic
  /// load failure with the full Retry / Sign-In / Cancel set.
  public var isSessionExpired: Bool {
    if case .sessionExpired = self { return true }
    return false
  }

  public var errorDescription: String? {
    switch self {
    case .urlMalformed(let url):
      String(format: "integration_internal_error_invalid_url".localized, String(reflecting: url))
    case .urlFromComponents:
      "integration_internal_error_build_url".localized
    case .noClient(let name):
      String(format: "integration_internal_error_no_client".localized, name)
    case .unexpectedResponse(let code):
      if let code {
        String(
          format: "integration_error_unexpected_response_with_code".localized,
          code,
          HTTPURLResponse.localizedString(forStatusCode: code)
        )
      } else {
        "integration_error_unexpected_response".localized
      }
    case .clientError(let code):
      switch code {
      case 401:
        "integration_error_unauthorized".localized
      default:
        String(
          format: "integration_error_unexpected_response_with_code".localized,
          code,
          HTTPURLResponse.localizedString(forStatusCode: code)
        )
      }
    case .sessionExpired(let serverName):
      String(format: "integration_error_session_expired".localized, serverName)
    case .serverMessage(let code, let message):
      String(format: "integration_error_server_message".localized, code, message)
    case .insecureTransport:
      // Shares the footer's string: the same sentence serves both, and duplicating it only
      // gave Lokalise the same text twice across 26 locales with room to drift apart.
      "integration_sso_requires_https".localized
    case .ssoNoAuthorizationCode(let providerCallbackURL):
      String(format: "integration_error_sso_no_code".localized, providerCallbackURL)
    }
  }
}
