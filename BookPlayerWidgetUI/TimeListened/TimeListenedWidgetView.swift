//
//  TimeListenedWidgetView.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 3/12/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct TimeListenedProvider: IntentTimelineProvider {
  typealias Entry = TimeListenedEntry

  func placeholder(in context: Context) -> TimeListenedEntry {
    return TimeListenedEntry(
      date: Date(),
      title: "Las played book title",
      theme: SimpleTheme.getDefaultTheme(),
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

  func getSnapshot(
    for configuration: PlayAndSleepActionIntent,
    in context: Context,
    completion: @escaping (TimeListenedEntry) -> Void
  ) {
    completion(placeholder(in: context))
  }

  func getTimeline(
    for configuration: PlayAndSleepActionIntent,
    in context: Context,
    completion: @escaping (Timeline<TimeListenedEntry>) -> Void
  ) {
    Task {
      do {
        let entry = try await getEntryForTimeline(for: configuration, context: context)

        completion(
          Timeline(entries: [entry], policy: .after(WidgetUtils.getNextDayDate()))
        )
      } catch {
        completion(
          Timeline(entries: [], policy: .after(WidgetUtils.getNextDayDate()))
        )
      }
    }
  }

  func getEntryForTimeline(
    for configuration: PlayAndSleepActionIntent,
    context: Context
  ) async throws -> TimeListenedEntry {
    let stack = try await DatabaseInitializer().loadCoreDataStack()
    let dataManager = DataManager(coreDataStack: stack)
    let libraryService = LibraryService(dataManager: dataManager)

    let records: [PlaybackRecordViewer]

    if context.family == .systemMedium {
      records = WidgetUtils.getPlaybackRecords(with: libraryService)
    } else {
      records = [WidgetUtils.getPlaybackRecord(with: libraryService)]
    }

    let theme = libraryService.getLibraryCurrentTheme() ?? SimpleTheme.getDefaultTheme()
    let autoplay = configuration.autoplay?.boolValue ?? true
    let seconds = TimeParser.getSeconds(from: configuration.sleepTimer)

    return TimeListenedEntry(
      date: Date(),
      title: libraryService.getLibraryLastItem()?.title,
      theme: theme,
      timerSeconds: seconds,
      autoplay: autoplay,
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
      TimeListenedWidgetView(entry: TimeListenedEntry(date: Date(), title: nil, theme: nil, timerSeconds: 300, autoplay: true, playbackRecords: WidgetUtils.getTestDataPlaybackRecords(.systemSmall)))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
      TimeListenedWidgetView(entry: TimeListenedEntry(date: Date(), title: nil, theme: nil, timerSeconds: 300, autoplay: true, playbackRecords: WidgetUtils.getTestDataPlaybackRecords(.systemMedium)))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
  }
}

struct TimeListenedWidget: Widget {
  let kind: String = "com.bookplayer.widget.small.timeListened"

  var body: some WidgetConfiguration {
    IntentConfiguration(kind: kind, intent: PlayAndSleepActionIntent.self, provider: TimeListenedProvider()) { entry in
      TimeListenedWidgetView(entry: entry)
    }
    .configurationDisplayName("Time Listened")
    .description("See how much time you have spent listening to audiobooks in the last few days")
    .supportedFamilies([.systemSmall, .systemMedium])
    .contentMarginsDisabledIfAvailable()
  }
}
