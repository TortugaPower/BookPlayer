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

  var eventPublisher = PassthroughSubject<String, Never>()

  init(
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol
  ) {
    self.playerManager = playerManager
    self.libraryService = libraryService
  }

  func playPause() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    let isPlaying = playerManager.isPlaying
    playerManager.playPause()
    let message = isPlaying
    ? "Paused"
    : "Playing"
    eventPublisher.send(message)
  }

  func rewind() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    playerManager.rewind()
    eventPublisher.send("Skipped back")
  }

  func forward() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    playerManager.forward()
    eventPublisher.send("Skipped forward")
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

    if let bookmark = self.libraryService.createBookmark(
      at: currentItem.currentTime,
      relativePath: currentItem.relativePath,
      type: .user
    ) {
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
