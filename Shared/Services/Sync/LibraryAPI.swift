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
  case remoteFileURL(path: String)
  case remoteContentsURL(path: String)
  case delete(path: String)
  case shallowDelete(path: String)
}

extension LibraryAPI: Endpoint {
  public var path: String {
    switch self {
    case .contents:
      return "/v1/library"
    case .upload:
      return "/v1/library"
    case .remoteFileURL:
      return "/v1/library"
    case .remoteContentsURL:
      return "/v1/library"
    case .delete:
      return "/v1/library"
    case .shallowDelete:
      return "/v1/library/folder_in_out"
    }
  }

  public var method: HTTPMethod {
    switch self {
    case .contents:
      return .get
    case .upload:
      return .put
    case .remoteFileURL:
      return .get
    case .remoteContentsURL:
      return .get
    case .delete:
      return .delete
    case .shallowDelete:
      return .delete
    }
  }

  public var parameters: [String: Any]? {
    switch self {
    case .contents(let path):
      return ["relativePath": path]
    case .upload(params: let params):
      return params
    case .remoteFileURL(let path):
      return [
        "relativePath": path,
        "sign": true
      ]
    case .remoteContentsURL(let path):
      return [
        "relativePath": "\(path)/",
        "sign": true
      ]
    case .delete(let path):
      return ["relativePath": path]
    case .shallowDelete(let path):
      return ["relativePath": path]
    }
  }
}
