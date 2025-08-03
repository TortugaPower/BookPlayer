//
//  AccountPerksSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct AccountPerksSectionView: View {
  @EnvironmentObject private var theme: ThemeViewModel

  var action: () -> Void

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: Spacing.S1) {
        Text("BookPlayer Pro")
          .bpFont(Fonts.title)
          .foregroundStyle(theme.primaryColor)
          .frame(maxWidth: .infinity)
        Label {
          Text("benefits_cloudsync_title")
            .bpFont(Fonts.titleRegular)
            .foregroundStyle(theme.primaryColor)
        } icon: {
          Image(systemName: "icloud.and.arrow.up.fill")
            .foregroundStyle(theme.linkColor)
        }
        Label {
          Text("Apple Watch (Beta)")
            .bpFont(Fonts.titleRegular)
            .foregroundStyle(theme.primaryColor)
        } icon: {
          Image(systemName: "applewatch.radiowaves.left.and.right")
            .foregroundStyle(theme.linkColor)
        }
        Label {
          Text("benefits_themesicons_title")
            .bpFont(Fonts.titleRegular)
            .foregroundStyle(theme.primaryColor)
        } icon: {
          Image(systemName: "paintpalette.fill")
            .foregroundStyle(theme.linkColor)
        }

        Button(action: action) {
          Text("completeaccount_title")
            .contentShape(Rectangle())
            .bpFont(Fonts.headline)
            .frame(height: 45)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(Color(UIColor(hex: "687AB7")))
            .cornerRadius(6)
            .padding(.top, Spacing.S1)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

#Preview {
  AccountPerksSectionView {}
    .environmentObject(ThemeViewModel())
}
