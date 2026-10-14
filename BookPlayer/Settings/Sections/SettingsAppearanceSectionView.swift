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
  @AppStorage(Constants.UserDefaults.appIcon, store: UserDefaults(suiteName: Constants.ApplicationGroupIdentifier))
  var appIcon: String = "Default"
  @AppStorage(Constants.UserDefaults.macOSTextScale)
  var textScaleIndex: Double = 0.0  // Default to 1.0x (index 0)
  @State
  var orientationLock: Bool

  @EnvironmentObject var theme: ThemeViewModel

  /// Calculate display label from index (e.g., "1.0x", "1.1x")
  private var scaleLabel: String {
    let scale = 1.0 + (textScaleIndex * 0.1)
    return String(format: "%.1fx", scale)
  }

  init() {
    self._orientationLock = .init(
      initialValue: UserDefaults.standard.object(forKey: Constants.UserDefaults.orientationLock) != nil
    )
  }

  var body: some View {
    ThemedSection {
      NavigationLink(value: SettingsScreen.themes) {
        Text("settings_theme_title")
          .bpFont(.body)
          .badge(
            Text(theme.title)
              .foregroundStyle(theme.secondaryColor)
          )
      }
      .settingsRowBackground(for: .themes)

      if ProcessInfo.processInfo.isiOSAppOnMac {
        VStack(alignment: .leading, spacing: Spacing.S1) {
          HStack {
            Text("settings_text_size_title")
              .bpFont(.body)
            Spacer()
            Text(scaleLabel)
              .bpFont(.body)
              .foregroundStyle(theme.secondaryColor)
          }

          Slider(
            value: $textScaleIndex,
            in: 0...20,
            step: 1
          ) {
            Text("settings_text_size_title")
              .bpFont(.body)
          } minimumValueLabel: {
            Text("A")
              .bpFont(.caption)
              .padding(.trailing, Spacing.S2)
          } maximumValueLabel: {
            Text("A")
              .bpFont(.title2)
              .padding(.leading, Spacing.S2)
          }
        }
      } else {
        NavigationLink(value: SettingsScreen.icons) {
          Text("settings_app_icon_title")
            .bpFont(.body)
            .badge(
              Text(appIcon)
                .foregroundStyle(theme.secondaryColor)
            )
        }
        .settingsRowBackground(for: .icons)

        /// iPad ignores the lock: apps that support multitasking get every orientation
        if UIDevice.current.userInterfaceIdiom == .phone {
          Toggle(isOn: $orientationLock) {
            Text("settings_lock_orientation_title")
              .bpFont(.body)
          }
          .onChange(of: orientationLock) {
            let window = WindowHelper.activeWindow

            if orientationLock {
              OrientationLock.save(window?.windowScene?.effectiveGeometry.interfaceOrientation)
            } else {
              OrientationLock.clear()
            }

            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
          }
        }
      }
    } header: {
      Text("settings_appearance_title".localized)
        .bpFont(.subheadline)
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
