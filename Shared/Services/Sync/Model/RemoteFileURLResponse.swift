//
//  RemoteFileURLResponse.swift
//  BookPlayer
//
//  Created by gianni.carlo on 9/2/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation

public struct RemoteFileURL: Decodable {
  public let url: URL
  public let relativePath: String

  enum CodingKeys: CodingKey {
    case url, relativePath
  }
}

struct RemoteFileURLResponseContainer: Decodable {
  let content: [RemoteFileURL]

  enum CodingKeys: CodingKey {
    case content
  }
}
