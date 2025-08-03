//
//  WidgetRenderModeModifier.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct WidgetRenderModeModifier: ViewModifier {
  @Environment(\.widgetRenderingMode) var renderingMode

  func body(content: Content) -> some View {
    if renderingMode == .accented {
      content
        .luminanceToAlpha()
        .widgetAccentable()
    } else {
      content
    }
  }
}

extension View {
  func bpWidgetAccentable() -> some View {
    modifier(WidgetRenderModeModifier())
  }
}
