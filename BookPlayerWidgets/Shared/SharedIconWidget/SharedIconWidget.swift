//
//  SharedIconWidget.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/11/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
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

@available(iOSApplicationExtension 16.1, watchOS 9.0, *)
struct SharedIconWidget: Widget {
  let kind: String = Constants.Widgets.sharedIconWidget.rawValue
  #if os(watchOS)
  let imageName = "Graphic Circular"
  #else
  let imageName = "logo-nopadding"
  #endif

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: SharedIconWidgetTimelineProvider()) { _ in
        Image(imageName)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .padding(0)
          .widgetAccentable()
          .widgetBackground(backgroundView: Color.clear)
      }
      .configurationDisplayName("Icon")
      .description("Quickly launch BookPlayer")
      .supportedFamilies([.accessoryCircular])
  }
}
