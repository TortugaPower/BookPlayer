//
//  LibraryAPI.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 24/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

public enum LibraryAPI {
  case contents(path: String)
  case upload(params: [String: Any])
}

extension LibraryAPI: Endpoint {
  public var path: String {
    switch self {
    case .contents:
      return "/v1/library"
    case .upload:
      return "/v1/library"
    }
  }

  public var method: HTTPMethod {
    switch self {
    case .contents:
      return .get
    case .upload:
      return .put
    }
  }

  public var parameters: [String: Any]? {
    switch self {
    case .contents(let path):
      return ["relativePath": path]
    case .upload(params: let params):
      return params
    }
  }
}