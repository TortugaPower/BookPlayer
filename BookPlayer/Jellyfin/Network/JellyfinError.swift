//
//  JellyfinError.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-22.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

enum JellyfinError: Error, LocalizedError {
  case urlMalformed(_ url: URL?)
  case urlFromComponents(_ components: URLComponents)
  case noClient
  case unexpectedResponse(code: Int?)
  case clientError(code: Int)

  var errorDescription: String? {
    switch self {
    case .urlMalformed(let url):
      String(format: "jellyfin_internal_error_invalid_url".localized, String(reflecting: url))
    case .urlFromComponents:
      "jellyfin_internal_error_build_url".localized
    case .noClient:
      "jellyfin_internal_error_no_client".localized
    case .unexpectedResponse(let code):
      if let code {
        String(
          format: "jellyfin_error_unexpected_response_with_code".localized,
          code,
          HTTPURLResponse.localizedString(forStatusCode: code)
        )
      } else {
        "jellyfin_error_unexpected_response".localized
      }
    case .clientError(let code):
      switch code {
      case 401:
        "jellyfin_error_unauthorized".localized
      default:
        String(
          format: "jellyfin_error_unexpected_response_with_code".localized,
          code,
          HTTPURLResponse.localizedString(forStatusCode: code)
        )
      }
    }
  }
}
