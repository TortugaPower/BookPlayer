//
//  BookmarkType.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@objc public enum BookmarkType: Int16 {
  case user, play, skip

  public func getNote() -> String? {
    switch self {
    case .user:
      return nil
    case .play:
      return Loc.BookmarkAutomaticPlayTitle.string
    case .skip:
      return Loc.BookmarkAutomaticSkipTitle.string
    }
  }
}
