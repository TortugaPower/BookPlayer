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
  let prevChapterImageName: String
  let nextChapterImageName: String
  let chapterTitle: String

  var formattedCurrentTime: String {
    self.currentTime.toFormattedTime()
  }

  var formattedMaxTime: String? {
    guard let maxTime = self.maxTime else { return nil }

    let formattedTime = abs(maxTime).toFormattedTime()

    if maxTime < 0 {
      return "-".appending(formattedTime)
    } else {
      return formattedTime
    }
  }
}
