//
//  BookPlayerError.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/11/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

public enum BookPlayerError: Error {
  case runtimeError(String)
  case emptyResponse
}

extension BookPlayerError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .runtimeError(let string):
      return string
    case .emptyResponse:
      return "Empty network response"
    }
  }
}
