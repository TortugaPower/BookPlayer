//
//  GlobalSpeedSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct GlobalSpeedSectionView: View {
  @AppStorage(Constants.UserDefaults.globalSpeedEnabled) var globalSpeedEnabled: Bool = false
  @AppStorage(Constants.UserDefaults.quickSpeedFirstPreference)
  var quickSpeedFirstPreference: Double = 1.0
  @AppStorage(Constants.UserDefaults.quickSpeedSecondPreference)
  var quickSpeedSecondPreference: Double = 2.0
  @AppStorage(Constants.UserDefaults.quickSpeedThirdPreference)
  var quickSpeedThirdPreference: Double = 3.0

  private let speedOptions: [Double] = stride(from: 50, through: 400, by: 5).map { Double($0) / 100.0 }

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      Picker("Quick Action 1", selection: $quickSpeedFirstPreference) {
        ForEach(speedOptions, id: \.self) { interval in
          Text(formatSpeed(interval))
            .tag(interval)
            .foregroundStyle(theme.linkColor)
        }
      }
      .pickerStyle(.menu)
      Picker("Quick Action 2", selection: $quickSpeedSecondPreference) {
        ForEach(speedOptions, id: \.self) { interval in
          Text(formatSpeed(interval))
            .tag(interval)
            .foregroundStyle(theme.linkColor)
        }
      }
      .pickerStyle(.menu)
      Picker("Quick Action 3", selection: $quickSpeedThirdPreference) {
        ForEach(speedOptions, id: \.self) { interval in
          Text(formatSpeed(interval))
            .tag(interval)
            .foregroundStyle(theme.linkColor)
        }
      }
      .pickerStyle(.menu)
      Toggle("settings_globalspeed_title", isOn: $globalSpeedEnabled)
    } header: {
      Text("speed_title".localized.capitalized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("settings_globalspeed_description")
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  Form {
    GlobalSpeedSectionView()
  }
  .environmentObject(ThemeViewModel())
}
