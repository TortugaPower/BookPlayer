//
//  BookLibraryMatcher.swift
//  BookPlayer
//
//  Created by dawsonamf on 6/28/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

@MainActor
struct BookLibraryMatcher {
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let durationTolerance: Int

  init(
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    durationTolerance: Int = 5
  ) {
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.durationTolerance = durationTolerance
  }

  /// Same content within duration tolerance. Chapter count is intentionally not
  /// compared here; it only breaks ties between candidates (see `find`)
  func matches(_ candidate: BookFingerprint, _ target: BookFingerprint) -> Bool {
    candidate.titleNormalized == target.titleNormalized
      && candidate.authorNormalized == target.authorNormalized
      && candidate.fileCount == target.fileCount
      && abs(candidate.durationRounded - target.durationRounded) <= durationTolerance
  }

  func find(matching fingerprint: BookFingerprint) -> SimpleLibraryItem? {
    let searchResults =
      libraryService.searchAllBooks(
        query: fingerprint.titleNormalized,
        limit: nil,
        offset: nil
      ) ?? []

    let candidates: [(item: SimpleLibraryItem, fingerprint: BookFingerprint)] = searchResults.compactMap { item in
      guard item.duration.isFinite,
        abs(Int(item.duration.rounded()) - fingerprint.durationRounded) <= durationTolerance,
        BookFingerprint.normalize(item.title) == fingerprint.titleNormalized,
        let playable = try? playbackService.getPlayableItem(from: item)
      else { return nil }

      // fingerprint the playable form so author/chapter/file semantics match the sharer's
      let candidateFingerprint = BookFingerprint(from: playable)

      guard matches(candidateFingerprint, fingerprint) else { return nil }

      return (item, candidateFingerprint)
    }

    guard !candidates.isEmpty else { return nil }

    if let chapterMatch = candidates.first(where: { $0.fingerprint.chapterCount == fingerprint.chapterCount }) {
      return chapterMatch.item
    }

    return candidates.min(by: {
      abs($0.fingerprint.durationRounded - fingerprint.durationRounded)
        < abs($1.fingerprint.durationRounded - fingerprint.durationRounded)
    })?.item
  }
}
