//
//  DeleteUserBookData.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 7/3/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

struct DeleteUserBookData: Codable {
  let deleteUserBook: DeleteUserBookResult

  enum CodingKeys: String, CodingKey {
    case deleteUserBook = "delete_user_book"
  }

  struct DeleteUserBookResult: Codable {
    let bookID: Int
    
    enum CodingKeys: String, CodingKey {
      case bookID = "book_id"
    }
  }
}