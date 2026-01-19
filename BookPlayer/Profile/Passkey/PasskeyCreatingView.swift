//
//  PasskeyCreatingView.swift
//  BookPlayer
//
//  Created by Claude on 1/17/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct PasskeyCreatingView: View {
  let email: String

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    VStack(spacing: Spacing.M) {
      Text("passkey_creating".localized)
        .font(.headline)
        .padding(.top, Spacing.S2)
      Text(email)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      ProgressView()
        .scaleEffect(1.5)
        .padding(.top, Spacing.S2)
      Spacer()
    }
    .frame(maxWidth: .infinity)
    .applyListStyle(with: theme, background: theme.systemGroupedBackgroundColor)
    .navigationTitle("passkey_registration_title".localized)
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    PasskeyCreatingView(email: "test@example.com")
  }
  .environmentObject(ThemeViewModel())
}
