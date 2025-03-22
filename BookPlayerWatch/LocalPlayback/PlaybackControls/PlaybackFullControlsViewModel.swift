//
//  PlaybackFullControlsViewModel.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 22/3/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import Foundation

final class PlaybackFullControlsViewModel: ObservableObject {
  let playerManager: PlayerManager

  var rate: Float {
    self.playerManager.currentSpeed
  }

  var boostVolume: Bool {
    UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled)
  }

  init(playerManager: PlayerManager) {
    self.playerManager = playerManager
  }

  func handleBoostVolumeToggle(_ flag: Bool) {
    self.playerManager.setBoostVolume(flag)
  }

  func handleNewSpeed(_ rate: Float) {
    let roundedValue = round(rate * 100) / 100.0

    guard roundedValue >= 0.5 && roundedValue <= 4.0 else { return }

    self.playerManager.setSpeed(roundedValue)
  }

  func handleNewSpeedJump() {
    let rate: Float

    if self.rate == 4.0 {
      rate = 0.5
    } else {
      rate = min(self.rate + 0.5, 4.0)
    }

    let roundedValue = round(rate * 100) / 100.0

    self.playerManager.setSpeed(roundedValue)
  }

}
