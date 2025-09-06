//
//  VerticalLabelStyle.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 22/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct VerticalLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack {
      configuration.icon
        .aspectRatio(contentMode: .fit)
        .frame(width: 24, height: 24)
      configuration.title
    }
  }
}

extension LabelStyle where Self == VerticalLabelStyle {
  static var vertical: VerticalLabelStyle { .init() }
}

#Preview {
  Label("Hello", systemImage: "arrow.up.circle")
    .labelStyle(.vertical)
}
