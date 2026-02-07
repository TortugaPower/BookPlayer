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
  @EnvironmentObject var theme: ThemeViewModel
  
  var body: some View {
    HStack(spacing: 21) {
      SettingsTipView(tipOption: .kind, purchaseCompleted: purchaseCompleted)
        .frame(width: 100)
        .background(theme.tertiarySystemBackgroundColor)
      SettingsTipView(tipOption: .excellent, purchaseCompleted: purchaseCompleted)
        .frame(width: 100)
        .background(theme.tertiarySystemBackgroundColor)
      SettingsTipView(tipOption: .incredible, purchaseCompleted: purchaseCompleted)
        .frame(width: 100)
        .background(theme.tertiarySystemBackgroundColor)
    }
  }
}

#Preview {
  SettingsTipOptionsView {}
    .environmentObject(ThemeViewModel())
}
