//
//  SpeedService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

/// sourcery: AutoMockable
public protocol SpeedServiceProtocol {
  func setSpeed(_ newValue: Float, relativePath: String?)
  func getSpeed(relativePath: String?) -> Float
}

class SpeedService: SpeedServiceProtocol {
  private let libraryService: LibraryServiceProtocol

  public private(set) var currentSpeed = CurrentValueSubject<Float, Never>(1.0)

  public init(libraryService: LibraryServiceProtocol) {
    self.libraryService = libraryService
  }

  public func setSpeed(_ newValue: Float, relativePath: String?) {
    if let relativePath = relativePath {
      self.libraryService.updateBookSpeed(at: relativePath, speed: newValue)
    }

    // set global speed
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled) {
      UserDefaults.standard.set(newValue, forKey: "global_speed")
    }

    self.currentSpeed.value = newValue
  }

  public func getSpeed(relativePath: String?) -> Float {
    let speed: Float

    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled) {
      speed = UserDefaults.standard.float(forKey: "global_speed")
    } else if let relativePath = relativePath {
      speed = self.libraryService.getItemSpeed(at: relativePath)
    } else {
      speed = self.currentSpeed.value
    }

    self.currentSpeed.value = speed > 0 ? speed : 1.0

    return self.currentSpeed.value
  }
}
