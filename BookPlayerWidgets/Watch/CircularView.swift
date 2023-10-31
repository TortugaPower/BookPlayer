//
//  CircularView.swift
//  BookPlayerWidgetsWatch
//
//  Created by Gianni Carlo on 29/10/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI
import WidgetKit

struct CircularView: View {
  let title: String
  let fillFraction: Double

  var body: some View {
    ProgressView(value: fillFraction) {
      Image("Graphic Circular")
        .resizable()
        .padding()
    }
    .widgetAccentable()
      .progressViewStyle(CircularProgressViewStyle())
      .widgetLabel {
        Text(title)
      }
  }
}

/// Note: Previews are not included because of a bug with Xcode where it tries to build
/// iOS only dependencies for WatchOS previews
/// https://developer.apple.com/forums/thread/715189
