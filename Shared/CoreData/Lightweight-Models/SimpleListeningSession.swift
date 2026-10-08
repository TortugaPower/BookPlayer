//
//  SimpleListeningSession.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SimpleListeningSession: Codable, Identifiable, Hashable {
  public let id: String
  public let relativePath: String
  public let itemTitle: String
  public let subtitle: String?
  public let artworkRelativePath: String?
  public let startedAt: Date
  public let endedAt: Date?
  public let duration: Double

  public init(
    id: String,
    relativePath: String,
    itemTitle: String,
    subtitle: String? = nil,
    artworkRelativePath: String? = nil,
    startedAt: Date,
    endedAt: Date?,
    duration: Double
  ) {
    self.id = id
    self.relativePath = relativePath
    self.itemTitle = itemTitle
    self.subtitle = subtitle
    self.artworkRelativePath = artworkRelativePath
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.duration = duration
  }

  /// Presentation built from denormalized session fields (no library lookup).
  public var presentation: ListeningHistoryPresentation {
    ListeningHistoryPresentation(
      title: itemTitle,
      subtitle: subtitle,
      artworkRelativePath: artworkRelativePath ?? relativePath,
      loadRelativePath: relativePath
    )
  }
}

extension SimpleListeningSession {
  public init(from session: ListeningSession) {
    self.init(
      id: session.id,
      relativePath: session.relativePath,
      itemTitle: session.itemTitle,
      subtitle: session.subtitle,
      artworkRelativePath: session.artworkRelativePath,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      duration: session.duration
    )
  }
}
