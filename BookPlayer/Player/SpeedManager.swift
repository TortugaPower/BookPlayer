//
//  SpeedManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class SpeedManager {
  private let libraryService: LibraryServiceProtocol
  let speedOptions: [Float] = [
    3.5, 3.4, 3.3, 3.2, 3.1, 3,
    2.9, 2.8, 2.7, 2.6, 2.5, 2.4, 2.3, 2.2, 2.1, 2,
    1.9, 1.8, 1.75, 1.7, 1.6, 1.5, 1.4, 1.3, 1.25, 1.2, 1.15, 1.1, 1,
    0.9, 0.8, 0.75, 0.7, 0.6, 0.5
  ]

  public private(set) var currentSpeed = CurrentValueSubject<Float, Never>(1.0)

  public init(libraryService: LibraryServiceProtocol) {
    self.libraryService = libraryService
  }

  public func setSpeed(_ newValue: Float, relativePath: String?) {
    if let relativePath = relativePath {
      self.libraryService.updateBookSpeed(at: relativePath, speed: newValue)
    }

    // set global speed
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue) {
        UserDefaults.standard.set(newValue, forKey: "global_speed")
    }

    self.currentSpeed.value = newValue
  }

  public func getSpeed(relativePath: String?) -> Float {
    let speed: Float
    
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue) {
      speed = UserDefaults.standard.float(forKey: "global_speed")
    } else if let relativePath = relativePath {
      speed = self.libraryService.getItemSpeed(at: relativePath)
    } else {
      speed = self.currentSpeed.value
    }
    
    self.currentSpeed.value = speed > 0 ? speed : 1.0
    
    return self.currentSpeed.value
  }

  public func currentSpeedPublisher() -> AnyPublisher<Float, Never> {
    return self.currentSpeed.eraseToAnyPublisher()
  }
}
