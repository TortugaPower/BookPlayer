//
//  EmptySpeedServiceMock.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 18/5/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

@testable import BookPlayer

/// Empty class meant to be subclassed to adjust service for test conditions
class EmptySpeedServiceMock: SpeedServiceProtocol {
  func setSpeed(_ newValue: Float, relativePath: String?) {}

  func getSpeed(relativePath: String?) -> Float {
    return 1
  }
}
