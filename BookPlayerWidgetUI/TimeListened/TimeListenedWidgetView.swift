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
        TimeListenedEntry(date: Date(), library: nil, timerSeconds: 300, autoplay: true, playbackRecords: [])
    }

    func getSnapshot(for configuration: PlayAndSleepActionIntent, in context: Context, completion: @escaping (TimeListenedEntry) -> Void) {
        let library = DataManager.getLibrary()
        let autoplay = configuration.autoplay?.boolValue ?? true
        let seconds = TimeParser.getSeconds(from: configuration.sleepTimer)

        var records: [PlaybackRecordViewer]

        if context.family == .systemMedium {
            records = WidgetUtils.getPlaybackRecords()
        } else {
            records = [WidgetUtils.getPlaybackRecord()]
        }

        let entry = TimeListenedEntry(date: Date(),
                                      library: library,
                                      timerSeconds: seconds,
                                      autoplay: autoplay,
                                      playbackRecords: records)

        completion(entry)
    }

    func getTimeline(for configuration: PlayAndSleepActionIntent, in context: Context, completion: @escaping (Timeline<TimeListenedEntry>) -> Void) {
        let library = DataManager.getLibrary()
        let autoplay = configuration.autoplay?.boolValue ?? true
        let seconds = TimeParser.getSeconds(from: configuration.sleepTimer)

        var records: [PlaybackRecordViewer]

        if context.family == .systemMedium {
            records = WidgetUtils.getPlaybackRecords()
        } else {
            records = [WidgetUtils.getPlaybackRecord()]
        }

        let entries: [TimeListenedEntry] = [TimeListenedEntry(date: Date(), library: library, timerSeconds: seconds, autoplay: autoplay, playbackRecords: records)]

        let timeline = Timeline(entries: entries, policy: .after(WidgetUtils.getNextDayDate()))
        completion(timeline)
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
            TimeListenedWidgetView(entry: TimeListenedEntry(date: Date(), library: nil, timerSeconds: 300, autoplay: true, playbackRecords: WidgetUtils.getTestDataPlaybackRecords(.systemSmall)))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            TimeListenedWidgetView(entry: TimeListenedEntry(date: Date(), library: nil, timerSeconds: 300, autoplay: true, playbackRecords: WidgetUtils.getTestDataPlaybackRecords(.systemMedium)))
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
