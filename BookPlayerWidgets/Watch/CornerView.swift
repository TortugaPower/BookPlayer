//
//  CornerView.swift
//  BookPlayerWidgetsWatch
//
//  Created by Gianni Carlo on 28/10/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI
import WidgetKit

struct CornerView: View {
  let title: String
  let fillFraction: Double

  var body: some View {
    let view = Text(title)
      .font(.title)
      .widgetLabel {
        ProgressView(value: fillFraction)
          .widgetAccentable()
      }

    if #available(watchOS 10.0, *) {
      return view.widgetCurvesContent()
    } else {
      return view
    }
  }
}

/// Note: Previews are not included because of a bug with Xcode where it tries to build
/// iOS only dependencies for WatchOS previews
/// https://developer.apple.com/forums/thread/715189
