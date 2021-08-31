//
//  ProgressObject.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/8/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

struct ProgressObject {
  let currentTime: TimeInterval
  let progress: String?
  let maxTime: TimeInterval?
  let sliderValue: Float

  var formattedCurrentTime: String {
    return TimeParser.formatTime(self.currentTime)
  }

  var formattedMaxTime: String? {
    guard let maxTime = self.maxTime else { return nil }

    return TimeParser.formatTime(maxTime)
  }
}
