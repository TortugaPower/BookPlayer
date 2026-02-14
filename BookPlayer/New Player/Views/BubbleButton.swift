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

  let iconName: String?
  var labelText: String?
  var action: (() -> Void)?
  
  var body: some View {
    Button {
      action?()
    } label: {
      HStack {
        if let icon = iconName {
          Image(systemName: icon)
            .bpFont(.titleRegular)
            .foregroundColor(theme.primaryColor)
        }
        
        if let text = labelText {
          Text(text)
            .bpFont(.titleRegular)
            .foregroundColor(theme.primaryColor)
        }
      }
        .padding(12)
        .frame(minWidth: 42)        // 2. Sets your "preferred" minimum width
        .frame(height: 42)
        .liquidGlassBackground()
        .clipShape(Capsule())
    }
  }
}

#Preview {
  BubbleButton(iconName: "user")
}
