//
//  ExternalResource+CoreDataClass.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 13/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import CoreData

extension ExternalResource {
  public enum SyncStatus: String, Codable {
    case notSynced = "not_synced"
    case stream = "stream"
    case downloaded = "downloaded"
  }
  
  /// A provider that is a server the user connects to: it has a host, an item can stream
  /// from it, and progress can be pushed to it. The complement of a metadata service like
  /// Hardcover, which has none of those.
  ///
  /// A type of its own rather than a subset of `ProviderName` so the compiler carries the
  /// distinction: anything that only makes sense for a server — a stream URL, a host, the
  /// glyph in the library row — takes this and has no case left to answer with a placeholder.
  /// Deliberately NOT `RawRepresentable`: `ProviderName` owns the strings that reach Core
  /// Data, so there is no second spelling of them to drift.
  public enum MediaServerProvider {
    case jellyfin
    case audiobookshelf
  }

  public enum ProviderName: String, Codable, CaseIterable {
    case jellyfin
    case hardcover
    case audiobookshelf

    /// This provider as a media server, or nil for one that isn't.
    ///
    /// The switch has NO `default` on purpose: this is the one place the question is answered,
    /// so adding a provider case becomes a compile error here and whoever adds it has to say
    /// which side it falls on. Everything else derives from it — `isMediaServer`,
    /// `SimpleExternalResource.mediaServer`, the SQL filter in
    /// `LibraryService.findMediaServerResources(at:)`, and every switch that handles servers
    /// only (stream source, host display, progress push, the row glyph), each of which then
    /// gets the same compile error for the half of the question it answers.
    public var mediaServer: MediaServerProvider? {
      switch self {
      case .jellyfin: .jellyfin
      case .audiobookshelf: .audiobookshelf
      case .hardcover: nil
      }
    }

    /// Convenience over `mediaServer` where only the yes/no matters.
    public var isMediaServer: Bool {
      mediaServer != nil
    }

    /// The media-server providers as stored in `ExternalResource.providerName`, for an `IN`
    /// predicate.
    public static var mediaServerRawValues: [String] {
      allCases.filter(\.isMediaServer).map(\.rawValue)
    }
  }
}
