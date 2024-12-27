//
//  PlayerSettingsViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 21/5/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
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
    UserDefaults.sharedDefaults.bool(forKey: Constants.UserDefaults.chapterContextEnabled)
  }
  var prefersRemainingTime: Bool {
    UserDefaults.sharedDefaults.bool(forKey: Constants.UserDefaults.remainingTimeEnabled)
  }

  init() {
    self.playerListPrefersBookmarks = UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks)
  }

  func getTitleForPlayerListPreference(_ prefersBookmarks: Bool) -> String {
    let stringKey = prefersBookmarks ? "bookmarks_title" : "chapters_title"
    return stringKey.localized
  }

  func handleOptionSelected(_ option: PlayerListDisplayOption) {
    let prefersBookmarks = option == .bookmarks

    UserDefaults.standard.set(prefersBookmarks, forKey: Constants.UserDefaults.playerListPrefersBookmarks)

    self.playerListPrefersBookmarks = prefersBookmarks
  }

  func handlePrefersChapterContext(_ flag: Bool) {
    UserDefaults.sharedDefaults.set(flag, forKey: Constants.UserDefaults.chapterContextEnabled)
  }

  func handlePrefersRemainingTime(_ flag: Bool) {
    UserDefaults.sharedDefaults.set(flag, forKey: Constants.UserDefaults.remainingTimeEnabled)
  }
}
