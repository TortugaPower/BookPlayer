//
//  SettingsPrivacySectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsPrivacySectionView: View {
  @AppStorage(Constants.UserDefaults.crashReportsDisabled)
  var crashReportsDisabled: Bool = false
  @AppStorage(Constants.UserDefaults.skanAttributionDisabled)
  var skanAttributionDisabled: Bool = false
  @EnvironmentObject var theme: ThemeViewModel
  
  var body: some View {
    Section {
      Toggle(isOn: $crashReportsDisabled) {
        Text("settings_crash_reports_title")
          .bpFont(.body)
      }
      Toggle(isOn: $skanAttributionDisabled) {
        Text("settings_skan_attribution_title")
          .bpFont(.body)
      }
    } header: {
      Text("settings_privacy_title")
        .bpFont(.subheadline)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("settings_skan_attribution_description")
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  NavigationStack {
    Form {
      SettingsPrivacySectionView()
    }
  }
  .environmentObject(ThemeViewModel())
}
