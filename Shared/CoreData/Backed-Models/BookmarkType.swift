//
//  BookmarkType.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@objc public enum BookmarkType: Int16, Decodable {
  case user, play, skip
  
  public func getNote() -> String? {
    switch self {
    case .user:
      return nil
    case .play:
      return "bookmark_automatic_play_title".localized
    case .skip:
      return "bookmark_automatic_skip_title".localized
    }
  }
}
