//
//  ContentsResponse.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/7/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation

struct ContentsResponse: Decodable, BPLogger {
  let content: [SyncableItem]
  /// Only returns when querying the root level
  let lastItemPlayed: SyncableItem?
  /// Items in the listing the app couldn't read. Each is skipped, so one bad row can't fail
  /// the whole listing (and with it a first sync); a listing that skipped any is incomplete,
  /// so nothing local is deleted against it
  let skippedCount: Int

  enum CodingKeys: String, CodingKey {
    case content
    case lastItemPlayed
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let content = try container.decode(LossyDecodableArray<SyncableItem>.self, forKey: .content)
    for failure in content.failures {
      Self.logger.error("Skipped a library item the app can't read: \(failure)")
    }
    self.content = content.elements
    self.skippedCount = content.failures.count
    // Only used to restore the last book: an unreadable one is left out, not the listing
    self.lastItemPlayed = (try? container.decodeIfPresent(SyncableItem.self, forKey: .lastItemPlayed)) ?? nil
  }
}
