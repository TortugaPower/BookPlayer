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
    ThemedSection {
      Picker(selection: $quickSpeedFirstPreference) {
        ForEach(speedOptions, id: \.self) { interval in
          Text(formatSpeed(interval))
            .bpFont(.body)
            .tag(interval)
            .foregroundStyle(theme.linkColor)
        }
      } label: {
        Text("Quick Action 1")
          .bpFont(.body)
      }
      .pickerStyle(.menu)
      Picker(selection: $quickSpeedSecondPreference) {
        ForEach(speedOptions, id: \.self) { interval in
          Text(formatSpeed(interval))
            .bpFont(.body)
            .tag(interval)
            .foregroundStyle(theme.linkColor)
        }
      } label: {
        Text("Quick Action 2")
          .bpFont(.body)
      }
      .pickerStyle(.menu)
      Picker(selection: $quickSpeedThirdPreference) {
        ForEach(speedOptions, id: \.self) { interval in
          Text(formatSpeed(interval))
            .bpFont(.body)
            .tag(interval)
            .foregroundStyle(theme.linkColor)
        }
      } label: {
        Text("Quick Action 3")
          .bpFont(.body)
      }
      .pickerStyle(.menu)
      Toggle(isOn: $globalSpeedEnabled) {
        Text("settings_globalspeed_title")
          .bpFont(.body)
      }
    } header: {
      Text("speed_title".localized.capitalized)
        .bpFont(.subheadline)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("settings_globalspeed_description")
        .bpFont(.caption)
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
