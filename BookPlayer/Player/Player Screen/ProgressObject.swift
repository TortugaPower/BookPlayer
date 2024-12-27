//
//  ProgressObject.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/8/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

struct ProgressObject {
  let currentTime: TimeInterval
  let progress: String?
  let maxTime: TimeInterval?
  let sliderValue: Float
  let prevChapterImageName: String
  let nextChapterImageName: String
  let chapterTitle: String

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
