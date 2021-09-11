//
//  MiniPlayerViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import UIKit
import StoreKit

class MiniPlayerViewModel {
  private let playerManager: PlayerManager
  weak var coordinator: MiniPlayerCoordinator!

  init(playerManager: PlayerManager) {
    self.playerManager = playerManager
  }

  func currentBookObserver() -> Published<Book?>.Publisher {
    return self.playerManager.$currentBook
  }

  func isPlayingObserver() -> AnyPublisher<Bool, Never> {
    return self.playerManager.isPlayingPublisher
  }

  func handlePlayPauseAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    self.playerManager.playPause()
  }

  func showPlayer() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    self.coordinator.showPlayer()
  }
}
