//
//  SharedWidgetContainerView.swift
//  BookPlayerWidgetsWatch
//
//  Created by Gianni Carlo on 1/11/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI

@available(iOSApplicationExtension 16.0, watchOS 9.0, *)
struct SharedWidgetContainerView: View {
  let entry: SharedWidgetEntry

  @Environment(\.widgetFamily) var widgetFamily

  var body: some View {
    switch widgetFamily {
    case .accessoryCorner:
      CornerView(
        title: entry.chapterTitle,
        fillFraction: entry.percentCompleted
      )
      .widgetBackground(backgroundView: Color.clear)
    case .accessoryCircular:
      CircularView(
        title: entry.chapterTitle,
        fillFraction: entry.percentCompleted
      )
      .widgetBackground(backgroundView: Color.clear)
    case .accessoryRectangular, .accessoryInline:
      RectangularView(
        chapterTitle: entry.chapterTitle,
        bookTitle: entry.bookTitle
      )
      .widgetBackground(backgroundView: Color.clear)
    default:
      RectangularView(
        chapterTitle: entry.chapterTitle,
        bookTitle: entry.bookTitle
      )
      .widgetBackground(backgroundView: Color.clear)
    }
  }
}

/// Note: Previews are not included because of a bug with Xcode where it tries to build
/// iOS only dependencies for WatchOS previews
/// https://developer.apple.com/forums/thread/715189
