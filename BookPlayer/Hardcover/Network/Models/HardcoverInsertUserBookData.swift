//
//  HardcoverInsertUserBookData.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/27/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

struct HardcoverInsertUserBookData: Codable {
  let insertUserBook: InsertUserBookResult

  enum CodingKeys: String, CodingKey {
    case insertUserBook = "insert_user_book"
  }

  struct InsertUserBookResult: Codable {
    let id: Int
  }
}
