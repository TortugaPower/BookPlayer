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

  var prefersChapterContext: Bool {
    UserDefaults.standard.bool(forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
  }
  var prefersRemainingTime: Bool {
    UserDefaults.standard.bool(forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)
  }

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

  func handlePrefersChapterContext(_ flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
  }

  func handlePrefersRemainingTime(_ flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.remainingTimeEnabled.rawValue)
  }
}
