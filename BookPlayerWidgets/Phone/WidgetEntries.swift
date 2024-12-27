//
//  WidgetEntries.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/10/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import WidgetKit

struct SimpleEntry: TimelineEntry {
  let date: Date
  let title: String?
  let relativePath: String?
  let theme: SimpleTheme
  let isPlaying: Bool

  init(
    date: Date,
    title: String?,
    relativePath: String?,
    theme: SimpleTheme,
    isPlaying: Bool
  ) {
    self.date = date
    self.title = title
    self.relativePath = relativePath
    self.theme = theme
    self.isPlaying = isPlaying
  }

  init(
    date: Date,
    title: String?,
    relativePath: String?
  ) {
    self.date = date
    self.title = title
    self.relativePath = relativePath
    self.theme = SimpleTheme.getDefaultTheme()
    self.isPlaying = false
  }
}

struct LibraryEntry: TimelineEntry {
  let date: Date
  let items: [SimpleLibraryItem]
  let theme: SimpleTheme

  init(
    date: Date,
    items: [SimpleLibraryItem],
    theme: SimpleTheme
  ) {
    self.date = date
    self.items = items
    self.theme = theme
  }

  init(
    date: Date,
    items: [SimpleLibraryItem]
  ) {
    self.date = date
    self.items = items
    self.theme = SimpleTheme.getDefaultTheme()
  }
}

struct RecentlyPlayedEntry: TimelineEntry {
  let date: Date
  let items: [WidgetLibraryItem]
  let currentlyPlaying: String?
  let theme: SimpleTheme

  init(
    date: Date,
    items: [WidgetLibraryItem],
    currentlyPlaying: String?,
    theme: SimpleTheme
  ) {
    self.date = date
    self.items = items
    self.currentlyPlaying = currentlyPlaying
    self.theme = theme
  }

  init(
    date: Date,
    items: [WidgetLibraryItem],
    currentlyPlaying: String?
  ) {
    self.date = date
    self.items = items
    self.currentlyPlaying = currentlyPlaying
    self.theme = SimpleTheme.getDefaultTheme()
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
