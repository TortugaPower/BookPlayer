//
//  SharedWidgetContainerView.swift
//  BookPlayerWidgetsWatch
//
//  Created by Gianni Carlo on 1/11/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import SwiftUI

@available(iOSApplicationExtension 16.1, *)
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
    case .accessoryRectangular:
      RectangularView(
        chapterTitle: entry.chapterTitle,
        bookTitle: entry.bookTitle,
        details: entry.details,
        includeLogo: true
      )
      .widgetBackground(backgroundView: Color.clear)
    case .accessoryInline:
      RectangularView(
        chapterTitle: entry.chapterTitle,
        bookTitle: entry.bookTitle,
        details: entry.details,
        includeLogo: false
      )
      .widgetBackground(backgroundView: Color.clear)
    default:
      RectangularView(
        chapterTitle: entry.chapterTitle,
        bookTitle: entry.bookTitle,
        details: entry.details,
        includeLogo: true
      )
      .widgetBackground(backgroundView: Color.clear)
    }
  }
}

/// Note: Previews are not included because of a bug with Xcode where it tries to build
/// iOS only dependencies for WatchOS previews
/// https://developer.apple.com/forums/thread/715189
