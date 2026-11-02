//
//  MediaServerProvider+Icon.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

extension ExternalResource.MediaServerProvider {
  /// UI concern kept in the app target: putting an ImageResource on the Shared CoreData enum
  /// would couple both framework targets to the app's asset catalog.
  ///
  /// On `MediaServerProvider` rather than `ProviderName` because only a server earns a glyph:
  /// Hardcover is progress-sync, not a source, and had no logo to return here.
  var icon: ImageResource {
    switch self {
    case .jellyfin: .jellyfinIcon
    case .audiobookshelf: .audiobookshelfIcon
    }
  }

  /// Height of the mark in the library row's corner badge, per provider because one number
  /// cannot make these two look the same size: the symbols don't fill their boxes equally, so
  /// at a shared frame height Jellyfin's ink draws ~0.4pt shorter than Audiobookshelf's and
  /// reads as undersized beside it. These land both inks at ~10.7pt.
  ///
  /// The ceiling is not the corner's diagonal — nothing clips until well past 13. It is the
  /// ink's centre climbing above the cloud's, which is what makes a media-server row look
  /// misaligned against a cloud row above it. Raise these together, and not by much.
  var badgeHeight: CGFloat {
    switch self {
    case .jellyfin: 11.5
    case .audiobookshelf: 11
    }
  }
}
