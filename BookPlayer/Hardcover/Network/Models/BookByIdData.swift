//
//  BookByIdData.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Response model for fetching a single book by its Hardcover id.
struct BookByIdData: Codable {
  let books: [Book]

  struct Book: Codable {
    let id: Int
    let title: String
    let image: Artwork?
    let contributions: [Contribution]?

    struct Artwork: Codable {
      let url: String?
    }

    struct Contribution: Codable {
      let author: Author?

      struct Author: Codable {
        let name: String?
      }
    }
  }
}
