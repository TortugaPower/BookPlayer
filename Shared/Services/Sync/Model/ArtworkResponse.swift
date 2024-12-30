//
//  ArtworkResponse.swift
//  BookPlayer
//
//  Created by gianni.carlo on 20/5/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation

struct ArtworkResponse: Decodable {
  let thumbnailURL: URL

  enum CodingKeys: String, CodingKey {
    case thumbnailURL = "thumbnail_url"
  }
}
