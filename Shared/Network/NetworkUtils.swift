//
//  NetworkUtils.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation

public protocol Endpoint {
  var path: String { get }
  var method: HTTPMethod { get }
  var parameters: [String: Any]? { get }
}

public enum HTTPMethod: String {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case delete = "DELETE"
  case patch = "PATCH"
}

/// Protocol representing an empty response. Use `T.emptyValue()` to get an instance.
public protocol EmptyResponse {
  /// Empty value for the conforming type.
  ///
  /// - Returns: Value of `Self` to use for empty values.
  static func emptyValue() -> Self
}

/// Type representing an empty value. Use `Empty.value` to get the static instance.
public struct Empty: Codable {
  /// Static `Empty` instance used for all `Empty` responses.
  public static let value = Empty()
}

extension Empty: EmptyResponse {
  public static func emptyValue() -> Empty {
    value
  }
}
