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
}
