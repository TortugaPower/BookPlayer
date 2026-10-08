//
//  ListeningHistoryPresentation.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// How a listening-history row should present a session in the UI.
public struct ListeningHistoryPresentation: Hashable, Sendable {
  /// Folder breadcrumb, bound title, or book title.
  public let title: String
  /// Book title when `title` is a folder chain; outer folder when bound sits in a folder.
  public let subtitle: String?
  /// Path used for artwork lookup.
  public let artworkRelativePath: String
  /// Path passed to the player loader.
  public let loadRelativePath: String

  public init(
    title: String,
    subtitle: String?,
    artworkRelativePath: String,
    loadRelativePath: String
  ) {
    self.title = title
    self.subtitle = subtitle
    self.artworkRelativePath = artworkRelativePath
    self.loadRelativePath = loadRelativePath
  }
}
