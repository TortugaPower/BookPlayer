//
//  RectangularView.swift
//  BookPlayerWidgetsWatch
//
//  Created by Gianni Carlo on 31/10/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, watchOS 9.0, *)
struct RectangularView: View {
  let chapterTitle: String
  let bookTitle: String
  let details: String
  let includeLogo: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        if includeLogo {
          Image("Graphic Circular")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24)
        }
        Text(chapterTitle)
          .font(.headline)
        Spacer()
      }
      .widgetAccentable()
      .frame(maxWidth: .infinity)
      Text(bookTitle)
        .font(.body)
      Text(details)
        .font(.body)
    }
    .widgetLabel {
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
