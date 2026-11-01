//
//  UserBookReadData.swift
//  BookPlayer
//
//  Created by Pedro Iniguez on 10/31/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Response model for the read in progress of a book in the user's library: the started read
/// that isn't finished, where progress goes, with the editions its length can come from
struct ReadInProgressData: Codable {
  let userBooks: [UserBook]

  enum CodingKeys: String, CodingKey {
    case userBooks = "user_books"
  }

  struct UserBook: Codable {
    let id: Int
    let statusId: Int
    /// The library entry's edition, which a read without its own goes by
    let edition: Edition?
    let book: Book?
    let userBookReads: [Read]

    enum CodingKeys: String, CodingKey {
      case id
      case statusId = "status_id"
      case edition
      case book
      case userBookReads = "user_book_reads"
    }
  }

  struct Book: Codable {
    let defaultAudioEdition: Edition?
    let defaultEbookEdition: Edition?
    let defaultPhysicalEdition: Edition?
    /// The most read audiobook edition with a duration, for books whose defaults have no length
    let audioEditions: [Edition]?
    /// The most read edition with a page count
    let pagedEditions: [Edition]?

    enum CodingKeys: String, CodingKey {
      case defaultAudioEdition = "default_audio_edition"
      case defaultEbookEdition = "default_ebook_edition"
      case defaultPhysicalEdition = "default_physical_edition"
      case audioEditions = "audio_editions"
      case pagedEditions = "paged_editions"
    }

    /// Audiobook first, this being an audiobook app; ebook and print ones count in pages.
    /// The defaults, then the most read editions with a length: a book's defaults can have none
    var defaultEditions: [Edition?] {
      [
        defaultAudioEdition,
        defaultEbookEdition,
        defaultPhysicalEdition,
        audioEditions?.first,
        pagedEditions?.first,
      ]
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
struct UpdateUserBookReadData: Codable {
  let updateUserBookRead: Result

  enum CodingKeys: String, CodingKey {
    case updateUserBookRead = "update_user_book_read"
  }

  struct Result: Codable {
    let error: String?
  }
}

/// What a book's progress writes on Hardcover's read (`DatesReadInput`): seconds of an audiobook
/// edition, else pages. Hardcover's edition can be another recording than the file, so the
/// percentage is carried over, never the position
struct HardcoverReadProgress: Equatable {
  enum Unit: Equatable {
    case seconds
    case pages
  }

  static let audiobookFormat = 2

  let unit: Unit
  let value: Int
  /// The edition measured against, when the read had none: written with the progress, as
  /// Hardcover needs the read's edition to show it. Reads started by a status change have none
  let editionId: Int?

  var object: [String: Int] {
    var object = [unit == .seconds ? "progress_seconds" : "progress_pages": value]
    if let editionId {
      object["edition_id"] = editionId
    }
    return object
  }

  /// Why nothing is sent, for the log
  enum Skip: Error, Equatable {
    case outOfRange
    /// No edition with a length in its unit, the read's own nor any other
    case noLength
    case notAhead(current: Int, value: Int)
  }

  /// Measured against the read's edition when it has a length. Hardcover gives a read the book's
  /// default print edition by itself, which may have none: then, as with a read without one, the
  /// first of `fallbacks` with a length (the library entry's edition, then the book's defaults),
  /// written on the read with the progress. Nothing when the progress isn't ahead of what Hardcover
  /// has (a book listened to again from earlier, or another device ahead). Kept short of the end:
  /// reaching it finishes the read, and finishing is the Read status, set when the book is marked
  /// finished
  static func evaluate(
    percent: Double,
    read: ReadInProgressData.Read,
    fallbacks: [ReadInProgressData.Edition?] = []
  ) -> Result<HardcoverReadProgress, Skip> {
    guard percent > 0, percent < 100 else { return .failure(.outOfRange) }

    let candidates = ([read.edition] + fallbacks).compactMap { $0 }
    guard
      let (edition, unit, total) = candidates.lazy.compactMap(measure).first
    else { return .failure(.noLength) }

    /// Progress already on the read counts only in the edition it was recorded against
    let keepsEdition = edition.id == read.edition?.id
    let recorded = keepsEdition ? (unit == .seconds ? read.progressSeconds : read.progressPages) : nil
    let current = recorded ?? 0
    let value = min(Int(Double(total) * percent / 100), total - 1)
    guard value > current else { return .failure(.notAhead(current: current, value: value)) }

    return .success(HardcoverReadProgress(
      unit: unit,
      value: value,
      editionId: keepsEdition ? nil : edition.id
    ))
  }

  static func update(
    percent: Double,
    read: ReadInProgressData.Read,
    fallbacks: [ReadInProgressData.Edition?] = []
  ) -> HardcoverReadProgress? {
    try? evaluate(percent: percent, read: read, fallbacks: fallbacks).get()
  }

  /// The edition's unit and length: seconds for an audiobook, pages otherwise (as Hardcover's
  /// SDK does); an edition without a format counts as an audiobook when it has a recording length
  private static func measure(
    _ edition: ReadInProgressData.Edition
  ) -> (ReadInProgressData.Edition, Unit, Int)? {
    let isAudiobook = edition.readingFormatId.map { $0 == audiobookFormat } ?? (edition.audioSeconds != nil)
    guard let total = isAudiobook ? edition.audioSeconds : edition.pages, total > 1 else { return nil }

    return (edition, isAudiobook ? .seconds : .pages, total)
  }
}

/// When to send a book's progress: its first update right away, then at most once per
/// `interval`, with the latest one held until then or until playback pauses
struct HardcoverProgressSchedule {
  let interval: TimeInterval
  private var lastSent = [String: Date]()
  private var pending = [String: Double]()

  init(interval: TimeInterval) {
    self.interval = interval
  }

  /// The percentage to send now, if any; otherwise it's kept for later
  mutating func record(_ percent: Double, for relativePath: String, at now: Date) -> Double? {
    if let last = lastSent[relativePath], now.timeIntervalSince(last) < interval {
      pending[relativePath] = percent
      return nil
    }

    lastSent[relativePath] = now
    pending[relativePath] = nil
    return percent
  }

  /// Everything held back, to send now
  mutating func flush(at now: Date) -> [(relativePath: String, percent: Double)] {
    let held = pending.map { (relativePath: $0.key, percent: $0.value) }
    pending.removeAll()
    for entry in held {
      lastSent[entry.relativePath] = now
    }
    return held
  }
}
