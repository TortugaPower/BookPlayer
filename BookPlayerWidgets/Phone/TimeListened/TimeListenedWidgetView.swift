//
//  TimeListenedWidgetView.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 3/12/20.
//  Copyright © 2020 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct TimeListenedProvider: AppIntentTimelineProvider {
  typealias Entry = TimeListenedEntry

  let decoder = JSONDecoder()

  func placeholder(in context: Context) -> TimeListenedEntry {
    return TimeListenedEntry(
      date: Date(),
      title: "Las played book title",
      timerSeconds: 300,
      autoplay: true,
      playbackRecords: getSnapshotRecords(context: context)
    )
  }

  func getSnapshotRecords(context: Context) -> [PlaybackRecordViewer] {
    if context.family == .systemMedium {
      let (
        firstDay,
        secondDay,
        thirdDay,
        fourthDay,
        fifthDay,
        sixthDay,
        seventhDay,
        _
      ) = WidgetUtils.getDateRangesForListenedTime()

      return [
        PlaybackRecordViewer(time: 50, date: firstDay),
        PlaybackRecordViewer(time: 100, date: secondDay),
        PlaybackRecordViewer(time: 200, date: thirdDay),
        PlaybackRecordViewer(time: 300, date: fourthDay),
        PlaybackRecordViewer(time: 200, date: fifthDay),
        PlaybackRecordViewer(time: 100, date: sixthDay),
        PlaybackRecordViewer(time: 50, date: seventhDay)
      ]
    } else {
      return [PlaybackRecordViewer(time: 5000, date: Date())]
    }
  }

  func snapshot(for configuration: TimeListenedConfigurationIntent, in context: Context) async -> TimeListenedEntry {
    getEntryForTimeline(for: configuration, context: context)
  }

  func timeline(for configuration: TimeListenedConfigurationIntent, in context: Context) async -> Timeline<TimeListenedEntry> {
    let entry = getEntryForTimeline(for: configuration, context: context)

    return Timeline(entries: [entry], policy: .after(WidgetUtils.getNextDayDate()))
  }

  func getRecordsFromDefaults() -> [SimplePlaybackRecord] {
    guard
      let recordsData = UserDefaults.sharedDefaults.data(forKey: Constants.UserDefaults.sharedWidgetPlaybackRecords),
      let records = try? decoder.decode([SimplePlaybackRecord].self, from: recordsData)
    else {
      return []
    }

    return records
  }

  func getLastPlayedFromDefaults() -> PlayableItem? {
    guard
      let itemsData = UserDefaults.sharedDefaults.data(forKey: Constants.UserDefaults.sharedWidgetLastPlayedItems),
      let items = try? decoder.decode([PlayableItem].self, from: itemsData)
    else {
      return nil
    }

    return items.first
  }

  func getThemeFromDefaults() -> SimpleTheme {
    if let themeData = UserDefaults.sharedDefaults.data(
      forKey: Constants.UserDefaults.sharedWidgetTheme
    ), let widgetTheme = try? decoder.decode(SimpleTheme.self, from: themeData) {
      return widgetTheme
    } else {
      return SimpleTheme.getDefaultTheme()
    }
  }

  func getEntryForTimeline(
    for configuration: TimeListenedConfigurationIntent,
    context: Context
  ) -> TimeListenedEntry {
    let lastPlayed = getLastPlayedFromDefaults()
    let theme = getThemeFromDefaults()
    let records: [PlaybackRecordViewer]

    if context.family == .systemMedium {
      records = WidgetUtils.getPlaybackRecords()
    } else {
      records = [WidgetUtils.getLastPlaybackRecord()]
    }

    return TimeListenedEntry(
      date: Date(),
      title: lastPlayed?.title,
      theme: theme,
      timerSeconds: (configuration.sleepTimer ?? .cancel).seconds,
      autoplay: configuration.autoplay ?? true,
      playbackRecords: records
    )
  }
}

struct TimeListenedWidgetView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.widgetFamily) var widgetFamily
  var entry: TimeListenedProvider.Entry

  var body: some View {
    switch widgetFamily {
    case .systemMedium:
      TimeListenedMediumView(colorScheme: _colorScheme, entry: entry)
    default:
      TimeListenedSmallView(colorScheme: _colorScheme, entry: entry)
    }
  }
}

struct TimeListenedWidgetView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      TimeListenedWidgetView(entry: TimeListenedEntry(
        date: Date(),
        title: nil,
        timerSeconds: 300,
        autoplay: true,
        playbackRecords: WidgetUtils.getTestDataPlaybackRecords(.systemSmall)
      ))
      .previewContext(WidgetPreviewContext(family: .systemSmall))
      TimeListenedWidgetView(entry: TimeListenedEntry(
        date: Date(),
        title: nil,
        timerSeconds: 300,
        autoplay: true,
        playbackRecords: WidgetUtils.getTestDataPlaybackRecords(.systemMedium)
      ))
      .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
  }
}

struct TimeListenedWidget: Widget {
  let kind: String = "com.bookplayer.widget.small.timeListened"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: TimeListenedConfigurationIntent.self, provider: TimeListenedProvider()) { entry in
      TimeListenedWidgetView(entry: entry)
    }
    .configurationDisplayName("Time Listened")
    .description("See how much time you have spent listening to audiobooks in the last few days")
    .supportedFamilies([.systemSmall, .systemMedium])
    .contentMarginsDisabled()
  }
}
