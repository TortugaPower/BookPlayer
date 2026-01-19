//
//  ContinueWithPasskeyButton.swift
//  BookPlayer
//
//  Created by Claude on 1/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ContinueWithPasskeyButton: View {
  @EnvironmentObject private var theme: ThemeViewModel

  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: Spacing.S) {
        Image(systemName: "person.badge.key.fill")
        Text("passkey_continue_button".localized)
      }
      .bpFont(Fonts.body)
      .frame(maxWidth: .infinity)
      .foregroundColor(theme.linkColor)
    }
    .padding(.horizontal, Spacing.M)
  }
}

#Preview {
  ContinueWithPasskeyButton { }
    .environmentObject(ThemeViewModel())
}
