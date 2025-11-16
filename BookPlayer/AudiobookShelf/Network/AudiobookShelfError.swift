//
//  AudiobookShelfError.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

enum AudiobookShelfError: Error, LocalizedError {
  case urlMalformed(_ url: URL?)
  case urlFromComponents(_ components: URLComponents)
  case unexpectedResponse(code: Int?)
  case clientError(code: Int)

  var errorDescription: String? {
    switch self {
    case .urlMalformed(let url):
      String(format: "integration_internal_error_invalid_url".localized, String(reflecting: url))
    case .urlFromComponents:
      "integration_internal_error_build_url".localized
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
    }
  }
}
