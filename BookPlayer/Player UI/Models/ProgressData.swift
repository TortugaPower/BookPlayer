//
//  ProgressData.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 10/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import BookPlayerKit

@Observable
class ProgressData {
  var currentTime: TimeInterval = 0.0
  var progress: String? = nil
  var maxTime: TimeInterval? = nil
  var sliderValue: Float = 0
  var chapterTitle: String = ""

  var formattedCurrentTime: String {
    return TimeParser.formatTime(self.currentTime)
  }

  var formattedMaxTime: String? {
    guard let maxTime = self.maxTime else { return nil }

    let formattedTime = TimeParser.formatTime(abs(maxTime))

    if maxTime < 0 {
      return "-".appending(formattedTime)
    } else {
      return formattedTime
    }
  }
}
