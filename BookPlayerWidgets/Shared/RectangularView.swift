//
//  RectangularView.swift
//  BookPlayerWidgetsWatch
//
//  Created by Gianni Carlo on 31/10/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.0, watchOS 9.0, *)
struct RectangularView: View {
  let chapterTitle: String
  let bookTitle: String

  var body: some View {
    VStack {
      Text(chapterTitle)
        .font(.headline)
      Text(bookTitle)
        .font(.body)
    } .widgetLabel {
      ViewThatFits {
        Text(bookTitle)
        Text(chapterTitle)
      }
    }
  }
}

/// Note: Previews are not included because of a bug with Xcode where it tries to build
/// iOS only dependencies for WatchOS previews
/// https://developer.apple.com/forums/thread/715189
