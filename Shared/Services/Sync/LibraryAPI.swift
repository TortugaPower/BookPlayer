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
}

extension LibraryAPI: Endpoint {
  public var path: String {
    switch self {
    case .contents:
      return "/v1/library"
    }
  }

  public var method: HTTPMethod {
    switch self {
    case .contents:
      return .get
    }
  }

  public var parameters: [String: Any]? {
    switch self {
    case .contents(let path):
      return ["relativePath": path]
    }
  }
}

struct ContentsResponse: Decodable {
  let content: [SyncedItem]
}

public struct SyncedItem: Decodable {
  let relativePath: String
  let originalFileName: String
  let title: String
  let details: String
  let speed: Double?
  let currentTime: Double
  let duration: Double
  let percentCompleted: Double
  let isFinished: Bool
  let orderRank: Int
  let lastPlayDateTimestamp: Double?
  let type: SyncedItemType
}

public enum SyncedItemType: String, Decodable {
  case book, bound, folder
}
