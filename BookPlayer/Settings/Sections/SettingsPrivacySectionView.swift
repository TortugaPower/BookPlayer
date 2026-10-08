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
  @AppStorage(Constants.UserDefaults.listeningHistoryDisabled, store: .sharedDefaults)
  var listeningHistoryDisabled: Bool = false
  @EnvironmentObject var theme: ThemeViewModel
  @Environment(\.libraryService) private var libraryService

  var body: some View {
    ThemedSection {
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

    ThemedSection {
      Toggle(isOn: $listeningHistoryDisabled) {
        Text("settings_listening_history_disabled_title")
          .bpFont(.body)
      }
      .onChange(of: listeningHistoryDisabled) { _, isDisabled in
        if isDisabled {
          // Stop any in-flight session so we don't keep a dangling active row.
          libraryService.endListeningSession()
        }
      }
    } footer: {
      Text("settings_listening_history_disabled_description")
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
