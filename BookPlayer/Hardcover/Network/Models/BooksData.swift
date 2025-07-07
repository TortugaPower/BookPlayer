//
//  BooksData.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/27/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

struct BooksData: Codable {
  let search: SearchResults

  struct SearchResults: Codable {
    let results: SearchResponse

    struct SearchResponse: Codable {
      let hits: [Hit]

      struct Hit: Codable {
        let document: Book

        struct Book: Codable {
          let id: Int
          let title: String
          let authorNames: [String]
          let image: Artwork?

          enum CodingKeys: String, CodingKey {
            case id, title
            case authorNames = "author_names"
            case image
          }
          
          init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let value = try? container.decode(String.self, forKey: .id) {
              guard let id = Int(value) else {
                throw DecodingError.dataCorruptedError(
                  forKey: .id,
                  in: container,
                  debugDescription: "Invalid id string: \(value)"
                )
              }
              self.id = id
            } else {
              self.id = try container.decode(Int.self, forKey: .id)
            }
            
            self.title = try container.decode(String.self, forKey: .title)
            self.authorNames = try container.decode([String].self, forKey: .authorNames)
            self.image = try container.decodeIfPresent(Artwork.self, forKey: .image)
          }

          struct Artwork: Codable {
            let url: String?
          }
        }
      }
    }
  }
}
