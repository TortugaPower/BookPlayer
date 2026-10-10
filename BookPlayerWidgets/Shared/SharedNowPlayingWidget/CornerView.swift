//
//  CornerView.swift
//  BookPlayerWidgetsWatch
//
//  Created by Gianni Carlo on 28/10/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
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

    return view
      .widgetCurvesContent()
  }
}

/// Note: Previews are not included because of a bug with Xcode where it tries to build
/// iOS only dependencies for WatchOS previews
/// https://developer.apple.com/forums/thread/715189
