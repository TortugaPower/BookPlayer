//
//  ButtonFreeViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 2/9/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

final class ButtonFreeViewModel: ButtonFreeView.Model {
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol

  init(
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
  }

  override func disableTimer(_ flag: Bool) {
    // Disregard if it's already handled by setting
    guard !UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled) else {
      return
    }

    UIApplication.shared.isIdleTimerDisabled = flag
  }

  override func playPause() -> String? {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    guard let currentItem = playerManager.currentItem else { return nil }

    let isPlaying = playerManager.isPlaying
    playerManager.playPause()
    let formattedTime = TimeParser.formatTime(currentItem.currentTime)

    let message = isPlaying
    ? "\("paused_title".localized) (\(formattedTime))"
    : "\("playing_title".localized.capitalized) (\(formattedTime))"
    return message
  }

  override func rewind() -> String? {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    playerManager.rewind()
    return "skipped_back_title".localized
  }

  override func forward() -> String? {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    playerManager.forward()
    return "skipped_forward_title".localized
  }

  override func createBookmark() -> String? {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    guard let currentItem = playerManager.currentItem else { return nil }

    if let bookmark = self.libraryService.getBookmark(
      at: currentItem.currentTime,
      relativePath: currentItem.relativePath,
      type: .user
    ) {
      let formattedTime = TimeParser.formatTime(bookmark.time)
      return String.localizedStringWithFormat(
        "bookmark_exists_title".localized,
        formattedTime
      )
    }

    let currentTime = floor(currentItem.currentTime)

    if let bookmark = self.libraryService.createBookmark(
      at: currentTime,
      relativePath: currentItem.relativePath,
      type: .user
    ) {
      syncService.scheduleSetBookmark(
        relativePath: currentItem.relativePath,
        time: currentTime,
        note: nil
      )
      let formattedTime = TimeParser.formatTime(bookmark.time)
      return String.localizedStringWithFormat(
        "bookmark_created_title".localized,
        formattedTime
      )
    } else {
      return "file_missing_title".localized
    }
  }
}
