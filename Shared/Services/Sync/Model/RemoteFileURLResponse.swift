//
//  RemoteFileURLResponse.swift
//  BookPlayer
//
//  Created by gianni.carlo on 9/2/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation

struct RemoteFileURL: Decodable {
  let url: URL

  enum CodingKeys: CodingKey {
    case url
  }
}

struct RemoteFileURLResponseContainer: Decodable {
  let content: [RemoteFileURL]

  enum CodingKeys: CodingKey {
    case content
  }
}
