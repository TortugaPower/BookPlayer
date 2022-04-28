//
//  NetworkUtils.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
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
  case delete = "DELETE"
}
