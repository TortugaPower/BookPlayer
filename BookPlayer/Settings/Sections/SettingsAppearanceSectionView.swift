//
//  SettingsAppearanceSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsAppearanceSectionView: View {
  @AppStorage(Constants.UserDefaults.appIcon)
  var appIcon: String = "Default"
  @AppStorage(Constants.UserDefaults.orientationLock)
  var orientationLock: Bool = false
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      NavigationLink(value: SettingsScreen.themes) {
        Text("settings_theme_title")
          .badge(
            Text(theme.title)
              .foregroundColor(theme.secondaryColor)
          )
      }

      NavigationLink(value: SettingsScreen.icons) {
        Text("settings_app_icon_title")
          .badge(
            Text(appIcon)
              .foregroundColor(theme.secondaryColor)
          )
      }

      Toggle("settings_lock_orientation_title", isOn: $orientationLock)
    } header: {
      Text("settings_appearance_title".localized)
        .foregroundColor(theme.secondaryColor)
    }
  }
}

#Preview {
  NavigationStack {
    Form {
      SettingsAppearanceSectionView()
        .environmentObject(ThemeViewModel())
    }
  }
}
