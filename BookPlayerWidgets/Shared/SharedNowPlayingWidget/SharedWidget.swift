//
//  SharedWidget.swift
//  BookPlayerWidgetsWatch
//
//  Created by Gianni Carlo on 31/10/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

#if os(watchOS)
import BookPlayerWatchKit
#else
import BookPlayerKit
#endif
import SwiftUI
import WidgetKit

struct SharedWidgetTimelineProvider: TimelineProvider {
  typealias Entry = SharedWidgetEntry

  private var decoder = JSONDecoder()

  func placeholder(in context: Context) -> SharedWidgetEntry {
    let chapterTitle: String

    switch context.family {
    case .accessoryCorner, .accessoryCircular:
      chapterTitle = "CHP 1"
    case .accessoryRectangular, .accessoryInline:
      chapterTitle = "Chapter"
    default:
      chapterTitle = "Chapter"
    }

    return SharedWidgetEntry(
      chapterTitle: chapterTitle,
      bookTitle: "Book title",
      details: "Details",
      percentCompleted: 0.5
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (SharedWidgetEntry) -> Void) {
    Task {
      do {
        let entry = try await getEntryForTimeline(context: context)
        completion(entry)
      } catch {
        completion(placeholder(in: context))
      }
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SharedWidgetEntry>) -> Void) {
    Task {
      do {
        let entry = try await getEntryForTimeline(context: context)

        completion(Timeline(
          entries: [entry],
          policy: .never
        ))
      } catch {
        completion(Timeline(
          entries: [
            SharedWidgetEntry(
              chapterTitle: "-----",
              bookTitle: "-----",
              details: "-----",
              percentCompleted: 0
            )
          ],
          policy: .never
        ))
      }
    }
  }

  func getEntryForTimeline(context: Context) async throws -> SharedWidgetEntry {
    let currentItem: PlayableItem
#if os(watchOS)
    currentItem = try await getWatchLastPlayedItem()
#else
    currentItem = try getItemsFromDefaults()
#endif
    let chapterTitle: String

    switch context.family {
    case .accessoryCorner, .accessoryCircular:
      chapterTitle = "CHP \(currentItem.currentChapter.index)"
    case .accessoryRectangular, .accessoryInline:
      chapterTitle = currentItem.currentChapter.title
    default:
      chapterTitle = currentItem.currentChapter.title
    }

    let percentCompleted: Double = currentItem.percentCompleted.isFinite
    ? currentItem.percentCompleted
    : 0

    return SharedWidgetEntry(
      chapterTitle: chapterTitle,
      bookTitle: currentItem.title,
      details: currentItem.author,
      percentCompleted: percentCompleted / 100
    )
  }

  func getWatchLastPlayedItem() async throws -> PlayableItem {
    if UserDefaults.sharedDefaults.object(forKey: "rcUserId") != nil {
      guard
        let itemsData = UserDefaults.sharedDefaults.data(forKey: Constants.UserDefaults.sharedWidgetLastPlayedItems),
        let item = (try decoder.decode([PlayableItem].self, from: itemsData)).first
      else {
        throw BookPlayerError.emptyResponse
      }

      return item
    } else {
      guard
        let watchContextFileURL = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier
        )?.appendingPathComponent("WatchContextLastPlayed.data")
      else {
        throw BookPlayerError.emptyResponse
      }

      let data = try Data(contentsOf: watchContextFileURL)
      return try decoder.decode(PlayableItem.self, from: data)
    }
  }

  func getItemsFromDefaults() throws -> PlayableItem {
    guard
      let itemsData = UserDefaults.sharedDefaults.data(forKey: Constants.UserDefaults.sharedWidgetLastPlayedItems),
      let item = try? decoder.decode([PlayableItem].self, from: itemsData).first
    else {
      throw BookPlayerError.emptyResponse
    }

    let prefersChapterContext = UserDefaults.sharedDefaults.bool(
      forKey: Constants.UserDefaults.chapterContextEnabled
    )

    if prefersChapterContext,
       let currentChapter = item.currentChapter {
      item.percentCompleted = ((item.currentTime - currentChapter.start) / currentChapter.duration) * 100
    }

    return item
  }
}

@available(iOSApplicationExtension 16.1, watchOS 9.0, *)
struct SharedWidget: Widget {
  let kind: String = Constants.Widgets.sharedNowPlayingWidget.rawValue

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: SharedWidgetTimelineProvider()) { entry in
        SharedWidgetContainerView(entry: entry)
      }
      .configurationDisplayName("Now Playing")
      .description("See your last played book")
#if os(watchOS)
      .supportedFamilies([
        .accessoryCorner,
        .accessoryInline,
        .accessoryCircular,
        .accessoryRectangular
      ])
#else
      .supportedFamilies([
        .accessoryInline,
        .accessoryCircular,
        .accessoryRectangular
      ])
#endif
  }
}
