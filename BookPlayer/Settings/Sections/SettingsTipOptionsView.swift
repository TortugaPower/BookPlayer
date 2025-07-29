//
//  SettingsTipOptionsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 25/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsTipOptionsView: View {
  let purchaseCompleted: () -> Void

  var body: some View {
    HStack(spacing: 21) {
      SettingsTipView(tipOption: .kind, purchaseCompleted: purchaseCompleted)
        .frame(width: 100)
      SettingsTipView(tipOption: .excellent, purchaseCompleted: purchaseCompleted)
        .frame(width: 100)
      SettingsTipView(tipOption: .incredible, purchaseCompleted: purchaseCompleted)
        .frame(width: 100)
    }
  }
}

#Preview {
  SettingsTipOptionsView {}
    .environmentObject(ThemeViewModel())
}
