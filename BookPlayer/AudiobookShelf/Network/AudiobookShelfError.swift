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
  case noToken
  case unauthorized
  case notFound
  case unexpectedResponse(code: Int?)
  case clientError(code: Int)
  case serverError(code: Int)
  case networkError(_ error: Error)

  var errorDescription: String? {
    switch self {
    case .urlMalformed(let url):
      String(format: "audiobookshelf_internal_error_invalid_url".localized, String(reflecting: url))
    case .urlFromComponents:
      "audiobookshelf_internal_error_build_url".localized
    case .noToken:
      "audiobookshelf_internal_error_no_token".localized
    case .unauthorized:
      "audiobookshelf_error_unauthorized".localized
    case .notFound:
      "audiobookshelf_error_not_found".localized
    case .unexpectedResponse(let code):
      if let code {
        String(
          format: "audiobookshelf_error_unexpected_response_with_code".localized,
          code,
          HTTPURLResponse.localizedString(forStatusCode: code)
        )
      } else {
        "audiobookshelf_error_unexpected_response".localized
      }
    case .clientError(let code):
      String(
        format: "audiobookshelf_error_client_error".localized,
        code,
        HTTPURLResponse.localizedString(forStatusCode: code)
      )
    case .serverError(let code):
      String(
        format: "audiobookshelf_error_server_error".localized,
        code,
        HTTPURLResponse.localizedString(forStatusCode: code)
      )
    case .networkError(let error):
      error.localizedDescription
    }
  }
}
