//
//  ExternalResourceProvider+Icon.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

extension ExternalResource.ProviderName {
  /// UI concern kept in the app target: putting an ImageResource on the Shared CoreData enum
  /// would couple both framework targets to the app's asset catalog.
  var icon: ImageResource {
    switch self {
    case .jellyfin:
      return .jellyfinIcon
    case .hardcover:
      return .plusImageAppIcons
    case .audiobookshelf:
      return .audiobookshelfIcon
    }
  }
}
