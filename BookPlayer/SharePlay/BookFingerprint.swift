//
//  BookFingerprint.swift
//  BookPlayer
//
//  Created by dawsonamf on 6/28/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

/// Content-based identity for an audiobook, so two devices that imported the
/// same book independently (different relative paths and UUIDs) can recognize
/// it as the same content.
struct BookFingerprint: Codable, Hashable, Sendable {
  let titleNormalized: String
  let authorNormalized: String
  let durationRounded: Int
  let chapterCount: Int
  /// Distinct audio files backing the item; copies with different file layouts
  /// (single m4b vs bound folder of mp3s) can't be coordinated, so they must not match
  let fileCount: Int

  var identifier: String {
    "\(titleNormalized)|\(authorNormalized)|\(durationRounded)|\(chapterCount)|\(fileCount)"
  }

  static func normalize(_ string: String) -> String {
    string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// The "Unknown author" fallback is stored localized at import time; map it to
  /// an empty string so unknown-author copies match across device languages
  static func normalizeAuthor(_ author: String) -> String {
    let normalized = normalize(author)
    return normalized == normalize("voiceover_unknown_author".localized) ? "" : normalized
  }
}

extension BookFingerprint {
  init(from item: PlayableItem) {
    self.init(
      titleNormalized: Self.normalize(item.title),
      authorNormalized: Self.normalizeAuthor(item.author),
      durationRounded: item.duration.isFinite ? Int(item.duration.rounded()) : 0,
      chapterCount: item.chapters.count,
      fileCount: max(Set(item.chapters.map(\.relativePath)).count, 1)
    )
  }
}
