//
//  PlayerControlsViewModel.swift
//  BookPlayer
//
//  Created by Pavel Kyzmin on 09.01.2022.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class PlayerControlsViewModel: BaseViewModel<PlayerControlsCoordinator> {
  let playerManager: PlayerManagerProtocol
  let speedManager: SpeedManagerProtocol

  init(playerManager: PlayerManagerProtocol,
       speedManager: SpeedManagerProtocol) {
    self.playerManager = playerManager
    self.speedManager = speedManager
  }

  func currentSpeedPublisher() -> AnyPublisher<Float, Never> {
    return self.playerManager.currentSpeedPublisher()
  }

  func getMinimumSpeedValue() -> Double {
    return self.speedManager.minimumSpeed
  }

  func getMaximumSpeedValue() -> Double {
    return self.speedManager.maximumSpeed
  }

  func getCurrentSpeed() -> Double {
    return Double(self.playerManager.getCurrentSpeed())
  }

  func getBoostVolumeFlag() -> Bool {
    return UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)
  }

  func handleBoostVolumeToggle(flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)

    self.playerManager.boostVolume = flag
  }

  func handleSpeedChange(newValue: Double) {
    let roundedValue = round(newValue * 100) / 100.0

    self.speedManager.setSpeed(
      Float(roundedValue),
      relativePath: self.playerManager.currentItem?.relativePath
    )
  }
}
