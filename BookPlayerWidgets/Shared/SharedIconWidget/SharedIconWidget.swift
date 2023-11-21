//
//  SharedIconWidget.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/11/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

#if os(watchOS)
import BookPlayerWatchKit
#else
import BookPlayerKit
#endif
import SwiftUI
import WidgetKit

struct SharedIconWidgetTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> SharedIconWidgetEntry {
    return SharedIconWidgetEntry()
  }
  
  func getSnapshot(in context: Context, completion: @escaping (SharedIconWidgetEntry) -> Void) {
    completion(placeholder(in: context))
  }
  
  func getTimeline(in context: Context, completion: @escaping (Timeline<SharedIconWidgetEntry>) -> Void) {
    let timeline = Timeline(
      entries: [
        SharedIconWidgetEntry()
      ],
      policy: .never
    )
    completion(timeline)
  }
  
  typealias Entry = SharedIconWidgetEntry
}

@available(iOSApplicationExtension 16.0, watchOS 9.0, *)
struct SharedIconWidget: Widget {
  let kind: String = Constants.Widgets.sharedIconWidget.rawValue

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: SharedIconWidgetTimelineProvider()) { _ in
        ZStack {
          AccessoryWidgetBackground()
          Image("Graphic Circular")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(Spacing.S3)
            .widgetAccentable()
            .widgetBackground(backgroundView: Color.clear)
        }
      }
      .configurationDisplayName("Icon")
      .description("Quickly launch BookPlayer")
      .supportedFamilies([.accessoryCircular])
  }
}
