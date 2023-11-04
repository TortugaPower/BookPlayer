//
//  CircularView.swift
//  BookPlayerWidgetsWatch
//
//  Created by Gianni Carlo on 29/10/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI
import WidgetKit
#if os(watchOS)
import BookPlayerWatchKit
#else
import BookPlayerKit
#endif

@available(iOSApplicationExtension 16.0, watchOS 9.0, *)
struct CircularView: View {
  let title: String
  let fillFraction: Double

  var body: some View {
    ZStack {
      Gauge(
        value: fillFraction,
        in: 0...1,
        label: { Text("\(Int(fillFraction * 100))%") },
        currentValueLabel: {
          Image("Graphic Circular")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(.bottom, Spacing.S2)
            .padding([.top, .leading, .trailing], 4)
        }
      )
      .gaugeStyle(.accessoryCircular)
    }
    .widgetAccentable()
    .widgetLabel {
      Text(title)
    }
  }
}

/// Note: Previews are not included because of a bug with Xcode where it tries to build
/// iOS only dependencies for WatchOS previews
/// https://developer.apple.com/forums/thread/715189
