//
//  SpeedViewModel.swift
//  BookPlayer
//
//  Created by Pavel Kyzmin on 09.01.2022.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine

class SpeedViewModel: BaseViewModel<SpeedCoordinator> {
  private let playerManager: PlayerManagerProtocol
  let whiteColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)

  init(playerManager: PlayerManagerProtocol) {
    self.playerManager = playerManager
  }

  func currentSpeedObserver() -> AnyPublisher<Float, Never> {
    return self.playerManager.currentSpeedPublisher()
  }

  func getCurrentSpeed() -> Double {
    return Double(self.playerManager.getCurrentSpeed())
  }

  func setSpeed(val: Float) {
    self.playerManager.setSpeed(val, relativePath: self.playerManager.currentItem?.relativePath)
  }

  func getWhiteColor() -> UIColor {
    return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
  }

  func getBlackColor() -> UIColor {
    return UIColor(red: 0.0, green: 0.0, blue: 0, alpha: 1.0)
  }

  func getActiveColor() -> UIColor {
    return UIColor(red: 71/255, green: 122/255, blue: 196/255, alpha: 1.0)
  }
}
