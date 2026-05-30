//
//  IntegrationError.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

enum IntegrationError: Error, LocalizedError {
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

  /// True when the error is a recoverable re-auth case — the UI should offer a Sign-In-only
  /// recovery path that preserves the existing connection instead of treating it as a generic
  /// load failure with the full Retry / Sign-In / Cancel set.
  var isSessionExpired: Bool {
    if case .sessionExpired = self { return true }
    return false
  }

  var errorDescription: String? {
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
    }
  }
}
