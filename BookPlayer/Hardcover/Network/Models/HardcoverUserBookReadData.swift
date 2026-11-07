//
//  HardcoverUserBookReadData.swift
//  BookPlayer
//
//  Created by Pedro Iniguez on 10/31/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Response model for the read in progress of a book in the user's library: the started read
/// that isn't finished, where progress goes, with its edition, which progress is measured against
struct HardcoverReadInProgressData: Codable {
  let userBooks: [UserBook]

  enum CodingKeys: String, CodingKey {
    case userBooks = "user_books"
  }

  struct UserBook: Codable {
    let id: Int
    let statusId: Int
    let userBookReads: [Read]

    enum CodingKeys: String, CodingKey {
      case id
      case statusId = "status_id"
      case userBookReads = "user_book_reads"
    }
  }

  struct Read: Codable {
    let id: Int
    let progressPages: Int?
    let progressSeconds: Int?
    let edition: Edition?

    enum CodingKeys: String, CodingKey {
      case id
      case progressPages = "progress_pages"
      case progressSeconds = "progress_seconds"
      case edition
    }
  }

  struct Edition: Codable, Equatable {
    let id: Int
    let pages: Int?
    let audioSeconds: Int?
    /// 1 physical, 2 audiobook, 4 ebook
    let readingFormatId: Int?

    enum CodingKeys: String, CodingKey {
      case id
      case pages
      case audioSeconds = "audio_seconds"
      case readingFormatId = "reading_format_id"
    }
  }
}

/// Response model for `update_user_book_read`
struct HardcoverUpdateUserBookReadData: Codable {
  let updateUserBookRead: Result

  enum CodingKeys: String, CodingKey {
    case updateUserBookRead = "update_user_book_read"
  }

  struct Result: Codable {
    let error: String?
  }
}

/// What a book's progress writes on Hardcover's read (`DatesReadInput`): seconds when the read's
/// edition is an audiobook, else pages. Hardcover's edition can be another recording than the file,
/// so the percentage is carried over, never the position
struct HardcoverReadProgress: Equatable {
  enum Unit: Equatable {
    case seconds
    case pages
  }

  static let audiobookFormat = 2

  let unit: Unit
  let value: Int

  var object: [String: Int] {
    [unit == .seconds ? "progress_seconds" : "progress_pages": value]
  }

  /// Why nothing is sent, for the log
  enum Skip: Error, Equatable {
    case outOfRange
    /// The read has no edition, or its edition has no length in its unit. No other edition is
    /// picked for it: the edition on a user's read is theirs, and BookPlayer only chooses one when
    /// it adds the book
    case noLength
    case notAhead(current: Int, value: Int)
  }

  /// Measured against the read's own edition. Nothing when it has no length, or when the progress
  /// isn't ahead of what Hardcover has (a book listened to again from earlier, or another device
  /// ahead). Kept short of the end: reaching it finishes the read, and finishing is the Read status,
  /// set when the book is marked finished
  static func evaluate(
    percent: Double,
    read: HardcoverReadInProgressData.Read
  ) -> Result<HardcoverReadProgress, Skip> {
    guard percent > 0, percent < 100 else { return .failure(.outOfRange) }

    guard
      let edition = read.edition,
      let (unit, total) = measure(edition)
    else { return .failure(.noLength) }

    let current = (unit == .seconds ? read.progressSeconds : read.progressPages) ?? 0
    let value = min(Int(Double(total) * percent / 100), total - 1)
    guard value > current else { return .failure(.notAhead(current: current, value: value)) }

    return .success(HardcoverReadProgress(unit: unit, value: value))
  }

  static func update(
    percent: Double,
    read: HardcoverReadInProgressData.Read
  ) -> HardcoverReadProgress? {
    try? evaluate(percent: percent, read: read).get()
  }

  /// The edition's unit and length: seconds for an audiobook, pages otherwise (as Hardcover's
  /// SDK does); an edition without a format counts as an audiobook when it has a recording length
  private static func measure(_ edition: HardcoverReadInProgressData.Edition) -> (Unit, Int)? {
    let isAudiobook = edition.readingFormatId.map { $0 == audiobookFormat } ?? ((edition.audioSeconds ?? 0) > 0)
    guard let total = isAudiobook ? edition.audioSeconds : edition.pages, total > 1 else { return nil }

    return (isAudiobook ? .seconds : .pages, total)
  }
}

/// When to send a book's progress: whenever its percentage changes. BookPlayer's is a whole number,
/// so a 10-hour book moves every 6 minutes, and the progress feed it comes from arrives at most
/// every 10 seconds, with the latest value after playback stops: nothing is held back to send later.
/// Kept by the item's uuid, which stays the same when the book is moved or renamed
struct HardcoverProgressChanges {
  private var lastSent = [String: Double]()

  /// Whether `percent` is new for the item; it's then recorded as sent
  mutating func isNew(_ percent: Double, forItem uuid: String) -> Bool {
    guard lastSent[uuid] != percent else { return false }

    lastSent[uuid] = percent
    return true
  }
}
