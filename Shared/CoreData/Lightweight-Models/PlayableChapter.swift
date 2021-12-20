//
//  PlayableChapter.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/11/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

public struct PlayableChapter: Codable {
  public let title: String
  public let author: String
  public let start: TimeInterval
  public let duration: TimeInterval
  public let relativePath: String
  public let index: Int16

  public var end: TimeInterval {
    return start + duration
  }

  public var fileURL: URL {
    return DataManager.getProcessedFolderURL().appendingPathComponent(self.relativePath)
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
