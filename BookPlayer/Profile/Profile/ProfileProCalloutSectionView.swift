//
//  ProfileProCalloutSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 31/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProfileProCalloutSectionView: View {
  @EnvironmentObject private var theme: ThemeViewModel

  var action: () -> Void

  var body: some View {
    VStack {
      Text("BookPlayer Pro")
        .font(Font(Fonts.title))
        .accessibilityHidden(true)
      Button(action: action) {
        Text("learn_more_title")
          .bpFont(Fonts.buttonTextSmall)
          .padding(.horizontal, Spacing.S)
          .padding(.vertical, Spacing.S3)
          .background(theme.linkColor)
          .foregroundStyle(.white)
          .clipShape(Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("BookPlayer Pro. \("learn_more_title".localized)")
    }
  }
}

#Preview {
  ProfileProCalloutSectionView {}
    .environmentObject(ThemeViewModel())
}
