//
//  BubbleButton.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 10/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct BubbleButton: View {
  let iconName: String
  var action: (() -> Void)?
  
  var body: some View {
    Button {
      action?()
    } label: {
      Image(systemName: iconName)
        .bpFont(.titleRegular)
        .foregroundColor(.primary)
        .padding(14)
        .frame(width: 44, height: 44)
        .liquidGlassBackground()
        .clipShape(Circle())
    }
  }
}

#Preview {
  BubbleButton(iconName: "user")
}
