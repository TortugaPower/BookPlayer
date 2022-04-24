//
//  LibraryAPI.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 24/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

public enum LibraryAPI {
  case library
}

extension LibraryAPI: Endpoint {
  public var path: String {
    switch self {
    case .library:
      return "user/library"
    }
  }

  public var method: HTTPMethod {
    switch self {
    case .library:
      return .get
    }
  }

  public var parameters: [String: Any]? {
    switch self {
    case .library:
      return nil
    }
  }
}

struct SyncedItems: Decodable {
  let path: String
  let title: String
  let author: String
  let speed: Double
  let currentTime: Double
  let duration: Double
  let percentCompleted: Double
  let isFinished: Bool
  let orderRank: Int
  let lastPlayDate: Date // timestamp
  let type: String
}
