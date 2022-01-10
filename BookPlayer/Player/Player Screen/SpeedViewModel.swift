//
//  SpeedViewModel.swift
//  BookPlayer
//
//  Created by Pavel Kyzmin on 09.01.2022.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

import BookPlayerKit
import Combine

class SpeedViewModel: BaseViewModel<SpeedCoordinator> {
  private let playerManager: PlayerManagerProtocol
  private let libraryService: LibraryServiceProtocol
    
  init(playerManager: PlayerManagerProtocol,
       libraryService: LibraryServiceProtocol) {
    self.playerManager = playerManager
    self.libraryService = libraryService
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
