//
//  WidgetEntries.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/10/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import WidgetKit
import BookPlayerKit

struct SimpleEntry: TimelineEntry {
  let date: Date
  let title: String?
  let relativePath: String?
  let theme: SimpleTheme
  let timerSeconds: Double
  let autoplay: Bool

  init(
    date: Date,
    title: String?,
    relativePath: String?,
    theme: SimpleTheme,
    timerSeconds: Double,
    autoplay: Bool
  ) {
    self.date = date
    self.title = title
    self.relativePath = relativePath
    self.theme = theme
    self.timerSeconds = timerSeconds
    self.autoplay = autoplay
  }

  init(
    date: Date,
    title: String?,
    relativePath: String?,
    timerSeconds: Double,
    autoplay: Bool
  ) {
    self.date = date
    self.title = title
    self.relativePath = relativePath
    self.theme = SimpleTheme.getDefaultTheme()
    self.timerSeconds = timerSeconds
    self.autoplay = autoplay
  }
}

struct LibraryEntry: TimelineEntry {
  let date: Date
  let items: [SimpleLibraryItem]
  let theme: SimpleTheme
  let timerSeconds: Double
  let autoplay: Bool

  init(
    date: Date,
    items: [SimpleLibraryItem],
    theme: SimpleTheme,
    timerSeconds: Double,
    autoplay: Bool
  ) {
    self.date = date
    self.items = items
    self.theme = theme
    self.timerSeconds = timerSeconds
    self.autoplay = autoplay
  }

  init(
    date: Date,
    items: [SimpleLibraryItem],
    timerSeconds: Double,
    autoplay: Bool
  ) {
    self.date = date
    self.items = items
    self.theme = SimpleTheme.getDefaultTheme()
    self.timerSeconds = timerSeconds
    self.autoplay = autoplay
  }
}

struct TimeListenedEntry: TimelineEntry {
  let date: Date
  let title: String?
  let theme: SimpleTheme
  let timerSeconds: Double
  let autoplay: Bool
  let playbackRecords: [PlaybackRecordViewer]

  init(
    date: Date,
    title: String?,
    theme: SimpleTheme,
    timerSeconds: Double,
    autoplay: Bool,
    playbackRecords: [PlaybackRecordViewer]
  ) {
    self.date = date
    self.title = title
    self.theme = theme
    self.timerSeconds = timerSeconds
    self.autoplay = autoplay
    self.playbackRecords = playbackRecords
  }

  init(
    date: Date,
    title: String?,
    timerSeconds: Double,
    autoplay: Bool,
    playbackRecords: [PlaybackRecordViewer]
  ) {
    self.date = date
    self.title = title
    self.theme = SimpleTheme.getDefaultTheme()
    self.timerSeconds = timerSeconds
    self.autoplay = autoplay
    self.playbackRecords = playbackRecords
  }
}
