//
//  SettingsProBannerSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsProBannerSectionView: View {
  @EnvironmentObject var theme: ThemeViewModel
  var showPro: () -> Void

  var body: some View {
    HStack(spacing: Spacing.S) {
      Image(systemName: "applewatch.radiowaves.left.and.right")
        .resizable()
        .frame(width: 70, height: 50)
        .foregroundColor(theme.linkColor)
        .opacity(0.5)

      VStack(alignment: .leading, spacing: 0) {
        Text("BookPlayer Pro")
          .bpFont(Fonts.title)
          .padding(.bottom, Spacing.S5)
        Text("support_bookplayer_description".localized)
          .bpFont(Fonts.body)
          .padding(.bottom, Spacing.S1)

        Button("learn_more_title".localized, action: showPro)
          .bpFont(Fonts.buttonTextSmall)
          .padding(.horizontal, Spacing.S)
          .padding(.vertical, Spacing.S3)
          .background(theme.linkColor)
          .foregroundColor(.white)
          .clipShape(Capsule())
          .buttonStyle(PlainButtonStyle())
      }
    }
  }
}

#Preview {
  SettingsProBannerSectionView {}
    .environmentObject(ThemeViewModel())
}
