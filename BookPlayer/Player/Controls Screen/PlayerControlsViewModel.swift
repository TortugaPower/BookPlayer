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
  let speedStep: Float = 0.1
  let minimumSpeed: Double = 0.5
  let maximumSpeed: Double = 4.0

  init(playerManager: PlayerManagerProtocol) {
    self.playerManager = playerManager
  }

  func currentSpeedPublisher() -> Published<Float>.Publisher {
    return self.playerManager.currentSpeedPublisher()
  }

  func getMinimumSpeedValue() -> Float {
    return Float(self.minimumSpeed)
  }

  func getMaximumSpeedValue() -> Float {
    return Float(self.maximumSpeed)
  }

  func getCurrentSpeed() -> Float {
    return self.playerManager.currentSpeed
  }

  func getBoostVolumeFlag() -> Bool {
    return UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)
  }

  func handleBoostVolumeToggle(flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)

    self.playerManager.setBoostVolume(flag)
  }

  func roundSpeedValue(_ value: Float) -> Float {
    return round(value / self.speedStep) * self.speedStep
  }

  func handleSpeedChange(newValue: Float) {
    let roundedValue = round(newValue * 100) / 100.0

    self.playerManager.setSpeed(roundedValue)
  }
}
