//
//  WatchWidgets.swift
//  BookPlayerWidgetsWatch
//
//  Created by Gianni Carlo on 31/10/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI
import WidgetKit

struct WatchWidgetTimelineProvider: TimelineProvider {
  typealias Entry = WatchWidgetEntry

  func placeholder(in context: Context) -> WatchWidgetEntry {
    let chapterTitle: String

    switch context.family {
    case .accessoryCorner, .accessoryCircular:
      chapterTitle = "CHP 1"
    case .accessoryRectangular, .accessoryInline:
      chapterTitle = "Chapter"
    @unknown default:
      chapterTitle = "Chapter"
    }

    return WatchWidgetEntry(
      chapterTitle: chapterTitle,
      bookTitle: "Book title",
      percentCompleted: 0.5,
      chapterIndex: 1
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (WatchWidgetEntry) -> Void) {
    completion(placeholder(in: context))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWidgetEntry>) -> Void) {
    // TODO: Load the last played book to show real info
    completion(Timeline(entries: [placeholder(in: context)], policy: .never))
  }
}

struct WatchWidgetEntry: TimelineEntry {
  /// We don't provide multiple entries, just a single one
  let date = Date()
  let chapterTitle: String
  let bookTitle: String
  let percentCompleted: Double
  let chapterIndex: Int
}

struct WatchWidget: Widget {
  let kind: String = "com.bookplayer.watch.widget"
  @Environment(\.widgetFamily) var widgetFamily

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: WatchWidgetTimelineProvider()) { entry in
        switch widgetFamily {
        case .accessoryCorner:
          CornerView(
            title: entry.chapterTitle,
            fillFraction: entry.percentCompleted
          )
        case .accessoryCircular:
          CircularView(
            title: entry.chapterTitle,
            fillFraction: entry.percentCompleted
          )
        case .accessoryRectangular, .accessoryInline:
          RectangularView(
            chapterTitle: entry.chapterTitle,
            bookTitle: entry.bookTitle
          )
        @unknown default:
          RectangularView(
            chapterTitle: entry.chapterTitle,
            bookTitle: entry.bookTitle
          )
        }
      }
  }
}
