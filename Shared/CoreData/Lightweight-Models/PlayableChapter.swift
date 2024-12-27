//
//  PlayableChapter.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/11/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation

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
  public let index: Int16
  public let chapterOffset: TimeInterval

  public var end: TimeInterval {
    return start + duration
  }

  public var fileURL: URL {
    return DataManager.getProcessedFolderURL().appendingPathComponent(self.relativePath)
  }

  public init(
    title: String,
    author: String,
    start: TimeInterval,
    duration: TimeInterval,
    relativePath: String,
    remoteURL: URL?,
    index: Int16,
    chapterOffset: TimeInterval = 0
  ) {
    self.title = title
    self.author = author
    self.start = start
    self.duration = duration
    self.relativePath = relativePath
    self.remoteURL = remoteURL
    self.index = index
    self.chapterOffset = chapterOffset
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
