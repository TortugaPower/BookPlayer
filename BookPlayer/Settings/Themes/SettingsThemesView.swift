//
//  SettingsThemesView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsThemesView: View {
  @AppStorage(Constants.UserDefaults.systemThemeVariantEnabled)
  var systemModeEnabled: Bool = true

  @AppStorage(Constants.UserDefaults.themeBrightnessEnabled)
  var brightnessModeEnabled: Bool = false

  @AppStorage(Constants.UserDefaults.themeDarkVariantEnabled)
  var darkModeEnabled: Bool = false

  @AppStorage(Constants.UserDefaults.themeBrightnessThreshold)
  var sliderValue: Double = 0

  @State private var themes: [SimpleTheme] = ThemeManager.getLocalThemes()
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    List {
      ThemedSection {
        Toggle(isOn: $systemModeEnabled) {
          Text("theme_system_title")
            .bpFont(.body)
        }
        .onChange(of: systemModeEnabled) {
          handleSystemModeUpdate()
        }
        Toggle(isOn: $brightnessModeEnabled) {
          Text("theme_switch_title")
            .bpFont(.body)
        }
        .onChange(of: brightnessModeEnabled) {
          handleBrightnessModeUpdate()
        }
        .disabled(systemModeEnabled)

        if brightnessModeEnabled {
          ZStack {
            GeometryReader { geo in
              let width = geo.size.width - 5
              let brightness = (UIScreen.main.brightness * 100).rounded() / 100
              let xPos = (brightness * width) - 15
              Image(.currentScreenBrightnessIndicator)
                .foregroundStyle(theme.secondaryColor)
                .offset(x: xPos, y: -7)
            }
            Slider(value: $sliderValue, in: 0...1)
          }
          .padding(.vertical)
          .onChange(of: sliderValue) {
            handleSliderUpdate()
          }
        } else {
          Toggle(isOn: $darkModeEnabled) {
            Text("theme_dark_title")
              .bpFont(.body)
          }
          .onChange(of: darkModeEnabled) {
            handleDarkModeUpdate()
          }
          .disabled(systemModeEnabled)
        }
      } footer: {
        if brightnessModeEnabled {
          Text("settings_theme_autobrightness")
            .bpFont(.caption)
            .foregroundStyle(theme.secondaryColor)
        }
      }

      ThemedSection {
        ForEach(themes) { item in
          ThemesView(item: item)
        }
      } header: {
        Text("themes_caps_title")
          .bpFont(.subheadline)
          .foregroundStyle(theme.secondaryColor)
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .navigationTitle("themes_title")
    .navigationBarTitleDisplayMode(.inline)
    .unlocksWithTipJar()
  }

  func handleSystemModeUpdate() {
    guard !systemModeEnabled else {
      ThemeManager.shared.checkSystemMode()
      return
    }

    /// handle switching variant if the other toggle is enabled
    if brightnessModeEnabled {
      handleSliderUpdate()
    } else if ThemeManager.shared.useDarkVariant != darkModeEnabled {
      ThemeManager.shared.useDarkVariant = darkModeEnabled
    }
  }

  func handleDarkModeUpdate() {
    ThemeManager.shared.useDarkVariant = darkModeEnabled
  }

  func handleBrightnessModeUpdate() {
    guard !brightnessModeEnabled else {
      handleSliderUpdate()
      return
    }
    /// handle switching variant if the other toggle is enabled
    guard ThemeManager.shared.useDarkVariant != darkModeEnabled else { return }

    ThemeManager.shared.useDarkVariant = darkModeEnabled
  }

  func handleSliderUpdate() {
    let brightness = (UIScreen.main.brightness * 100).rounded() / 100
    let shouldUseDarkVariant = brightness <= CGFloat(sliderValue)

    if shouldUseDarkVariant != ThemeManager.shared.useDarkVariant {
      ThemeManager.shared.useDarkVariant = shouldUseDarkVariant
    }
  }
}

#Preview {
  @Previewable var accountService: AccountService = {
    let accountService = AccountService()
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: ""))
    accountService.setup(dataManager: dataManager)
    accountService.accessLevel = .free

    return accountService
  }()

  NavigationStack {
    SettingsThemesView()
  }
  .environmentObject(ThemeViewModel())
  .environment(\.accountService, accountService)
}
