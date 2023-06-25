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
    TimeListenedEntry(date: Date(), title: nil, theme: nil, timerSeconds: 300, autoplay: true, playbackRecords: [])
  }

  func getSnapshot(for configuration: PlayAndSleepActionIntent, in context: Context, completion: @escaping (TimeListenedEntry) -> Void) {

      let stack = DataMigrationManager().getCoreDataStack()
      stack.loadStore { _, error in
        guard error == nil else {
          completion(self.placeholder(in: context))
          return
        }

        Task { @MainActor in
          let dataManager = DataManager(coreDataStack: stack)
          let libraryService = LibraryService(dataManager: dataManager)

          var records: [PlaybackRecordViewer]

          if context.family == .systemMedium {
            records = await WidgetUtils.getPlaybackRecords(with: libraryService)
          } else {
            records = [await WidgetUtils.getPlaybackRecord(with: libraryService)]
          }

          let autoplay = configuration.autoplay?.boolValue ?? true
          let seconds = TimeParser.getSeconds(from: configuration.sleepTimer)

          let entry = TimeListenedEntry(
            date: Date(),
            title: libraryService.getLibraryLastItem()?.title,
            theme: libraryService.getLibraryCurrentTheme(),
            timerSeconds: seconds,
            autoplay: autoplay,
            playbackRecords: records
          )

          completion(entry)
        }
      }
  }

  func getTimeline(for configuration: PlayAndSleepActionIntent, in context: Context, completion: @escaping (Timeline<TimeListenedEntry>) -> Void) {
    let stack = DataMigrationManager().getCoreDataStack()
    stack.loadStore { _, error in
      guard error == nil else {
        completion(Timeline(entries: [], policy: .after(WidgetUtils.getNextDayDate())))
        return
      }

      Task { @MainActor in
        let dataManager = DataManager(coreDataStack: stack)
        let libraryService = LibraryService(dataManager: dataManager)

        var records: [PlaybackRecordViewer]

        if context.family == .systemMedium {
          records = await WidgetUtils.getPlaybackRecords(with: libraryService)
        } else {
          records = [await WidgetUtils.getPlaybackRecord(with: libraryService)]
        }

        let autoplay = configuration.autoplay?.boolValue ?? true
        let seconds = TimeParser.getSeconds(from: configuration.sleepTimer)

        let entry = TimeListenedEntry(
          date: Date(),
          title: libraryService.getLibraryLastItem()?.title,
          theme: libraryService.getLibraryCurrentTheme(),
          timerSeconds: seconds,
          autoplay: autoplay,
          playbackRecords: records
        )

        completion(Timeline(entries: [entry], policy: .after(WidgetUtils.getNextDayDate())))
      }
    }
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
  }
}
