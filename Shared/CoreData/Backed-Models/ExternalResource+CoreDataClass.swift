//
//  ExternalResource+CoreDataClass.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 13/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import CoreData
import SwiftUI

extension ExternalResource {
  public enum SyncStatus: String, Codable {
    case notSynced = "not_synced"
    case stream = "stream"
    case downloaded = "downloaded"
  }
  
  public enum ProviderName: String, Codable, CaseIterable {
    case jellyfin
    case hardcover
    case audiobookshelf

    /// Whether this provider is a server the user connects to, as opposed to a metadata
    /// service like Hardcover that has no host and streams nothing.
    ///
    /// The switch has NO `default` on purpose: this is the one place the question is answered,
    /// so adding a provider case becomes a compile error here and whoever adds it has to say
    /// which side it falls on. Everything else derives from it — `SimpleExternalResource
    /// .isMediaServer` and the SQL filter in `LibraryService.findMediaServerResources(at:)`.
    public var isMediaServer: Bool {
      switch self {
      case .jellyfin, .audiobookshelf: true
      case .hardcover: false
      }
    }

    /// The media-server providers as stored in `ExternalResource.providerName`, for an `IN`
    /// predicate.
    public static var mediaServerRawValues: [String] {
      allCases.filter(\.isMediaServer).map(\.rawValue)
    }
  }
}
