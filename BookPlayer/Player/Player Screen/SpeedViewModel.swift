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
    
  init(playerManager: PlayerManagerProtocol) {
    self.playerManager = playerManager
  }
    
    
  func currentSpeedObserver() -> AnyPublisher<Float, Never> {
    return self.playerManager.currentSpeedPublisher()
  }
    
    
  func getCurrentSpeed() -> Double {
    return Double(self.playerManager.getCurrentSpeed())
  }
    
    func setSpeed(val: Float) -> Void {
      self.playerManager.setSpeed(val, relativePath: self.playerManager.currentItem?.relativePath)
  }
}
