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
  @State
  var orientationLock: Bool

  @EnvironmentObject var theme: ThemeViewModel

  init() {
    self._orientationLock = .init(
      initialValue: UserDefaults.standard.object(forKey: Constants.UserDefaults.orientationLock) != nil
    )
  }

  var body: some View {
    Section {
      NavigationLink(value: SettingsScreen.themes) {
        Text("settings_theme_title")
          .badge(
            Text(theme.title)
              .foregroundStyle(theme.secondaryColor)
          )
      }

      NavigationLink(value: SettingsScreen.icons) {
        Text("settings_app_icon_title")
          .badge(
            Text(appIcon)
              .foregroundStyle(theme.secondaryColor)
          )
      }

      Toggle("settings_lock_orientation_title", isOn: $orientationLock)
        .onChange(of: orientationLock) {
          if orientationLock {
            UserDefaults.standard.set(
              UIDevice.current.orientation.rawValue,
              forKey: Constants.UserDefaults.orientationLock
            )
          } else {
            UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.orientationLock)
          }

          AppDelegate.shared?.activeSceneDelegate?.startingNavigationController
            .setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    } header: {
      Text("settings_appearance_title".localized)
        .foregroundStyle(theme.secondaryColor)
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
