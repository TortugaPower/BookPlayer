//
//  LastPlayedWidgetView.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 24/11/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct LastPlayedWidgetView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.widgetFamily) var widgetFamily
  var entry: LastPlayedProvider.Entry

  var body: some View {
    switch widgetFamily {
    case .systemMedium:
      RecentBooksWidgetView(entry: entry)
    default:
      LastPlayedView(
        model: .init(
          item: entry.items.first,
          isPlaying: entry.items.first?.relativePath == entry.currentlyPlaying,
          theme: entry.theme
        )
      )
    }
  }
}

struct LastPlayedWidget: Widget {
  let kind: String = Constants.Widgets.lastPlayedWidget.rawValue

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: LastPlayedProvider(),
      content: { entry in
        LastPlayedWidgetView(entry: entry)
      }
    )
    .configurationDisplayName("Last Played Books")
    .description("See and play your last played books")
    .supportedFamilies([.systemSmall, .systemMedium])
    .contentMarginsDisabledIfAvailable()
  }
}
