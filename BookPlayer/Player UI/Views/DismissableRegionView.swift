//
//  DismissableRegionView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct DismissableRegionView: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 3)
      .fill(Color.secondary.opacity(0.4))
      .frame(width: 60, height: 6)
      .padding(.vertical, 16)
      .contentShape(Rectangle())
  }
}

#Preview {
  DismissableRegionView()
}
