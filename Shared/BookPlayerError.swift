//
//  BookPlayerError.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/11/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation

public enum BookPlayerError: Error {
  case runtimeError(String)
  case networkError(String)
  case networkErrorWithCode(message: String, code: String)
  case cancelledTask
  case emptyResponse
}

extension BookPlayerError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .runtimeError(let string):
      return string
    case .emptyResponse:
      return "Empty network response"
    case .networkError(let message):
      return message
    case .networkErrorWithCode(let message, _):
      return message
    case .cancelledTask:
      return "Concurrent task was cancelled"
    }
  }
}
