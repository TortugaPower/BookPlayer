//
//  AudioBookActivity.swift
//  BookPlayer
//
//  Created by dawsonamf on 6/28/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import GroupActivities

struct AudioBookActivity: GroupActivity {
  let bookFingerprint: BookFingerprint
  let bookTitle: String
  /// Original-casing author for display on the receiving side ("" when unknown).
  let bookAuthor: String

  static let activityIdentifier = "com.tortugapower.audiobookplayer.shareplay.listen-together"

  var metadata: GroupActivityMetadata {
    var metadata = GroupActivityMetadata()
    metadata.title = String(format: "shareplay_activity_title".localized, bookTitle)
    metadata.type = .listenTogether
    return metadata
  }
}
