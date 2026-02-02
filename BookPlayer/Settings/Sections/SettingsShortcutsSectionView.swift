//
//  SettingsShortcutsSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AppIntents
import BookPlayerKit
import SwiftUI

struct SettingsShortcutsSectionView: View {
  @EnvironmentObject var theme: ThemeViewModel
  
  var body: some View {
    Section {
      ShortcutsLink()
        .shortcutsLinkStyle(theme.useDarkVariant ? .dark : .light)
    } header: {
      Text("settings_shortcuts_title")
        .bpFont(.subheadline)
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  NavigationStack {
    Form {
      SettingsShortcutsSectionView()
    }
  }
  .environmentObject(ThemeViewModel())
}
