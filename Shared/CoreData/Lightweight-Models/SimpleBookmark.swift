//
//  SimpleBookmark.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/4/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SimpleBookmark: Decodable, Identifiable {
  public var id: String {
    return UUID().uuidString
  }
  public let time: Double
  public let note: String?
  let type: BookmarkType
  public let relativePath: String

  static var fetchRequestProperties = [
    "time",
    "note",
    "type",
    "item.relativePath",
  ]

  public func getImageNameForType() -> String? {
    switch type {
    case .play:
      return "play"
    case .skip:
      return "clock.arrow.2.circlepath"
    case .sleep:
      return "moon"
    case .user:
      return nil
    }
  }

  public init(time: Double, note: String?, type: BookmarkType, relativePath: String) {
    self.time = time
    self.note = note
    self.type = type
    self.relativePath = relativePath
  }
}

extension SimpleBookmark: Equatable {
  public static func == (lhs: SimpleBookmark, rhs: SimpleBookmark) -> Bool {
    return lhs.time == rhs.time
      && lhs.relativePath == rhs.relativePath
  }
}

extension SimpleBookmark {
  init(from bookmark: SyncableBookmark) {
    self.relativePath = bookmark.key
    self.time = bookmark.time
    self.note = bookmark.note
    self.type = .user
  }
}
