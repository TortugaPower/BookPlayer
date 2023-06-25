//
//  ButtonFreeViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 2/9/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class ButtonFreeViewModel: BaseViewModel<ButtonFreeCoordinator> {
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol
  var eventPublisher = PassthroughSubject<String, Never>()

  init(
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
  }

  func disableTimer(_ flag: Bool) {
    // Disregard if it's already handled by setting
    guard !UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled.rawValue) else {
      return
    }

    UIApplication.shared.isIdleTimerDisabled = flag
  }

  func playPause() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    guard let currentItem = playerManager.currentItem else { return }

    let isPlaying = playerManager.isPlaying
    playerManager.playPause()
    let formattedTime = TimeParser.formatTime(currentItem.currentTime)

    let message = isPlaying
    ? "\("paused_title".localized) (\(formattedTime))"
    : "\("playing_title".localized.capitalized) (\(formattedTime))"
    eventPublisher.send(message)
  }

  func rewind() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    playerManager.rewind()
    eventPublisher.send("skipped_back_title".localized)
  }

  func forward() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    playerManager.forward()
    eventPublisher.send("skipped_forward_title".localized)
  }

  func createBookmark() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    guard let currentItem = playerManager.currentItem else { return }

    if let bookmark = self.libraryService.getBookmark(
      at: currentItem.currentTime,
      relativePath: currentItem.relativePath,
      type: .user
    ) {
      let formattedTime = TimeParser.formatTime(bookmark.time)
      let message = String.localizedStringWithFormat(
        "bookmark_exists_title".localized,
        formattedTime
      )
      eventPublisher.send(message)
      return
    }

    let currentTime = floor(currentItem.currentTime)

    Task { @MainActor in
      if let bookmark = await self.libraryService.createBookmark(
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
        let message = String.localizedStringWithFormat(
          "bookmark_created_title".localized,
          formattedTime
        )
        eventPublisher.send(message)
      } else {
        eventPublisher.send("file_missing_title".localized)
      }
    }
  }
}
