//
//  MediaAction.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 17/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit

enum MediaAction: CaseIterable, Identifiable {
  case speed
  case timer
  case bookmark
  case chapters
  case more
  
  var iconName: String {
    switch self {
    case .speed: return "arrow.2.circlepath.circle"
    case .timer: return "moon.fill"
    case .bookmark: return "bookmark"
    case .chapters: return "list.bullet"
    case .more: return "ellipsis"
    }
  }
  
  var iconOffset: CGPoint? {
    switch self {
    case .bookmark: return .init(x: 2, y: -1)
    default: return nil
    }
  }
  
  var accessibilityLabel: String {
    switch self {
    case .speed: 
      return ""
    case .timer:
      return "settings_siri_sleeptimer_title".localized
    case .bookmark:
      return "bookmark_create_title".localized
    case .chapters:
      return UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks)
        ? "bookmarks_title".localized
        : "chapters_title".localized
    case .more:
      return "more_title".localized
    }
  }
  
  var id: Self { self }
}
