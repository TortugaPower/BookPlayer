//
//  PlayerSettingsViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 21/5/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

final class PlayerSettingsViewModel {
  enum PlayerListDisplayOption {
    case chapters, bookmarks
  }

  @Published var playerListPrefersBookmarks: Bool

  init() {
    self.playerListPrefersBookmarks = UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks.rawValue)
  }

  func getTitleForPlayerListPreference(_ prefersBookmarks: Bool) -> String {
    let stringKey = prefersBookmarks ? "bookmarks_title" : "chapters_title"
    return stringKey.localized
  }

  func handleOptionSelected(_ option: PlayerListDisplayOption) {
    let prefersBookmarks = option == .bookmarks

    UserDefaults.standard.set(prefersBookmarks, forKey: Constants.UserDefaults.playerListPrefersBookmarks.rawValue)

    self.playerListPrefersBookmarks = prefersBookmarks
  }
}
