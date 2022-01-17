//
//  SpeedManagerMock.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 17/1/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
@testable import BookPlayer

class SpeedManagerMock: SpeedManagerProtocol {
  var minimumSpeed: Double = 0.5
  var maximumSpeed: Double = 5.0

  func setSpeed(_ newValue: Float, relativePath: String?) {}

  func getSpeed(relativePath: String?) -> Float { return 1.0 }
}
