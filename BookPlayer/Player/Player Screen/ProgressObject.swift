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

  let formattedCurrentTime: String
  let formattedMaxTime: String?

  init(currentTime: TimeInterval,
       progress: String?,
       maxTime: TimeInterval?,
       sliderValue: Float,
       prevChapterImageName: String,
       nextChapterImageName: String,
       chapterTitle: String
  ) {
    self.currentTime = currentTime
    self.progress = progress
    self.maxTime = maxTime
    self.sliderValue = sliderValue
    self.prevChapterImageName = prevChapterImageName
    self.nextChapterImageName = nextChapterImageName
    self.chapterTitle = chapterTitle

    self.formattedCurrentTime = currentTime.toFormattedTime()

    self.formattedMaxTime = {
      guard let maxTime = maxTime else { return nil }

      let formattedTime = abs(maxTime).toFormattedTime()

      if maxTime < 0 {
        return "-".appending(formattedTime)
      } else {
        return formattedTime
      }
    }()
  }
}

