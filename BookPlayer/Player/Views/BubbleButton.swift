//
//  BubbleButton.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 10/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct BubbleButton: View {
  @EnvironmentObject private var theme: ThemeViewModel

  let iconImage: Image?
  var imageOffset: CGPoint?
  var labelText: String?
  var action: (() -> Void)?

  var body: some View {
    Button {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      action?()
    } label: {
      HStack {
        if let myImage = iconImage {
          myImage
            .resizable()
            .scaledToFit()
            .foregroundColor(theme.primaryColor)
            .frame(width: 24, height: 24)
            .offset(x: imageOffset?.x ?? 0, y: imageOffset?.y ?? 0)
        }

        if let text = labelText {
          Text(text)
            .bpFont(.headline).monospacedDigit()
            .foregroundColor(theme.primaryColor)
        }
      }
      .padding(12)
      .frame(minWidth: 48)
      .frame(height: 48)
      .contentShape(Capsule())
      .liquidGlassBackground()
      .clipShape(Capsule())
    }
  }
}

#Preview {
  BubbleButton(iconImage: Image(systemName: MediaAction.timer.iconName))
}
