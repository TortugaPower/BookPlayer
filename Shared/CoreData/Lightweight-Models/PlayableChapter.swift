//
//  PlayableChapter.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/11/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

public struct PlayableChapter: Codable, Identifiable {
  public var id: String {
    return "\(index)"
  }
  public let title: String
  public let author: String
  public let start: TimeInterval
  public let duration: TimeInterval
  public let relativePath: String
  public let remoteURL: URL?
  public var externalUrl: URL?
  public let index: Int16
  public let chapterOffset: TimeInterval
  public let externalHeaders: [String: String]
  
  public var end: TimeInterval {
    return start + duration
  }

  public var fileURL: URL {
    return DataManager.getProcessedFolderURL().appendingPathComponent(self.relativePath)
  }

  /// Whether the chapter's file is a video, based on its file extension.
  /// Derives the type from `relativePath` directly rather than `fileURL`, which
  /// would resolve (and create) the processed folder just to read a path extension.
  public var isVideo: Bool {
    URL(fileURLWithPath: relativePath).fileType?.conforms(to: .movie) ?? false
  }

  public init(
    title: String,
    author: String,
    start: TimeInterval,
    duration: TimeInterval,
    relativePath: String,
    remoteURL: URL?,
    externalURL: URL?,
    index: Int16,
    chapterOffset: TimeInterval = 0,
    externalHeaders: [String: String] = [:]
  ) {
    self.title = title
    self.author = author
    self.start = start
    self.duration = duration
    self.relativePath = relativePath
    self.remoteURL = remoteURL
    self.externalUrl = externalURL
    self.index = index
    self.chapterOffset = chapterOffset
    self.externalHeaders = externalHeaders
  }

  /// `externalUrl`/`externalHeaders` are deliberately EXCLUDED from Codable: the headers carry
  /// the media server's live `Authorization` token, and encoded `PlayableItem`s travel through
  /// the WatchConnectivity application context, which the system PERSISTS TO DISK on both
  /// devices. Both values are per-device, resolved from the local connection at load time
  /// (`PlaybackService.getPlayableChapters`), so there is nothing to transport — the receiving
  /// side re-resolves against its own saved connections.
  enum CodingKeys: String, CodingKey {
    case title, author, start, duration, relativePath, remoteURL, index, chapterOffset
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.title = try container.decode(String.self, forKey: .title)
    self.author = try container.decode(String.self, forKey: .author)
    self.start = try container.decode(TimeInterval.self, forKey: .start)
    self.duration = try container.decode(TimeInterval.self, forKey: .duration)
    self.relativePath = try container.decode(String.self, forKey: .relativePath)
    self.remoteURL = try container.decodeIfPresent(URL.self, forKey: .remoteURL)
    self.index = try container.decode(Int16.self, forKey: .index)
    self.chapterOffset = (try? container.decodeIfPresent(TimeInterval.self, forKey: .chapterOffset)) ?? 0
    self.externalUrl = nil
    self.externalHeaders = [:]
  }
}

extension PlayableChapter: Equatable {
  public static func == (lhs: PlayableChapter, rhs: PlayableChapter) -> Bool {
    return lhs.relativePath == rhs.relativePath
      && lhs.index == rhs.index
      && lhs.title == rhs.title
      && lhs.start == rhs.start
  }
}
