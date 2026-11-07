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

/// Response model for what adding a book needs to know first: whether the user already has it, and
/// the audiobook edition to add it with
struct HardcoverLibraryEntryData: Codable {
  let userBooks: [UserBook]
  let book: Book?

  enum CodingKeys: String, CodingKey {
    case userBooks = "user_books"
    case book = "books_by_pk"
  }

  struct UserBook: Codable {
    let id: Int
  }

  struct Book: Codable {
    let defaultAudioEdition: Edition?
    /// The most read audiobook edition with a duration, for books whose default has none
    let audioEditions: [Edition]?

    enum CodingKeys: String, CodingKey {
      case defaultAudioEdition = "default_audio_edition"
      case audioEditions = "audio_editions"
    }

    /// The default audiobook edition when it has a duration, else the most read one with a duration
    var audiobookEditionID: Int? {
      if let defaultAudioEdition, (defaultAudioEdition.audioSeconds ?? 0) > 0 {
        return defaultAudioEdition.id
      }

      return audioEditions?.first { ($0.audioSeconds ?? 0) > 0 }?.id
    }
  }

  struct Edition: Codable {
    let id: Int
    let audioSeconds: Int?

    enum CodingKeys: String, CodingKey {
      case id
      case audioSeconds = "audio_seconds"
    }
  }
}
